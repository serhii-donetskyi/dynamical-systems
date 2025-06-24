class DynamicalSystemsUI {
    constructor() {
        this.selectedComponents = {
            ode: null,
            solver: null,
            job: null
        };

        this.componentConfigs = {
            ode: {},
            solver: {},
            job: {}
        };

        this.fieldValidations = {
            ode: {
                args: {},
                variables: {},
                parameters: {}
            },
            solver: {
                args: {}
            },
            job: {
                args: {}
            }
        }

        this.components = {
            ode: {
                dropdown: {
                    select: document.getElementById('ode-dropdown-select')
                },
                arguments: {
                    section: document.getElementById('ode-arguments'),
                    fields: {
                        section: document.getElementById('ode-arguments-fields'),
                    },
                    apply: document.getElementById('ode-arguments-apply-btn')
                },
                state: {
                    section: document.getElementById('ode-state'),
                    variables: document.getElementById('ode-state-content-variables'),
                    parameters: document.getElementById('ode-state-content-parameters')
                }
            },
            solver: {
                dropdown: {
                    select: document.getElementById('solver-dropdown-select')
                },
                arguments: {
                    section: document.getElementById('solver-arguments'),
                    fields: {
                        section: document.getElementById('solver-arguments-fields'),
                    },
                }
            },
            job: {
                dropdown: {
                    select: document.getElementById('job-dropdown-select')
                },
                arguments: {
                    section: document.getElementById('job-arguments'),
                    fields: {
                        section: document.getElementById('job-arguments-fields'),
                    },
                }
            },
            run: {
                button: document.getElementById('run-btn')
            },
            cancel: {
                button: document.getElementById('cancel-btn')
            },
            testProgress: {
                button: document.getElementById('test-progress-btn')
            },
            progress: {
                section: document.getElementById('progress-section'),
                fill: document.getElementById('progress-fill'),
                percentage: document.getElementById('progress-percentage'),
                message: document.getElementById('progress-message')
            }
        }
        
        this.currentJobId = null;
        this.eventSource = null;
        
        this.init();
    }
    
    async init() {
        try {
            // Load all components in parallel
            const [odes, solvers, jobs] = await Promise.all([
                this.fetchAPI('/api/get-odes'),
                this.fetchAPI('/api/get-solvers'),
                this.fetchAPI('/api/get-jobs')
            ]);

            this.populateDropdown('ode', odes);
            this.populateDropdown('solver', solvers);
            this.populateDropdown('job', jobs);
        } catch (error) {
            console.error('Error loading components:', error);
            this.createPopUp(`Failed to load components: ${error}`, false);
        }
        
        // Dropdown change listeners
        this.components.ode.dropdown.select.addEventListener('change', (e) => {
            this.generateArgumentFields('ode', e.target.value);
        });
        
        this.components.solver.dropdown.select.addEventListener('change', (e) => {
            this.generateArgumentFields('solver', e.target.value);
        });
        
        this.components.job.dropdown.select.addEventListener('change', (e) => {
            this.generateArgumentFields('job', e.target.value);
        });

        this.components.ode.arguments.apply.addEventListener('click', () => {
            this.components.ode.arguments.apply.disabled = true;
            this.generateStateFields();
        });

        this.components.run.button.addEventListener('click', () => {
            this.runJob();
        });

        this.components.testProgress.button.addEventListener('click', () => {
            this.runMockJob();
        });
    }
    
    async fetchAPI(url, options = {}) {
        const config = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            },
            ...options
        };

        // If there's a body, stringify it
        if (config.body && typeof config.body === 'object') {
            config.body = JSON.stringify(config.body);
        }

        const response = await fetch(url, config);
        if (!response.ok) {
            const errorData = await response.json();
            const errorMessage = errorData.error || errorData.message || errorData.detail;
            throw errorMessage;
        }
        return await response.json();
    }

    populateDropdown(componentType, options) {
        const select = this.components[componentType].dropdown.select;
        while (select.children.length > 1) {
            select.removeChild(select.lastChild);
        }
        options.forEach(option => {
            const optionElement = document.createElement('option');
            optionElement.value = option;
            optionElement.textContent = option;
            select.appendChild(optionElement);
        });
    }

    async generateArgumentFields(componentType, componentName) {
        const section = this.components[componentType].arguments.section;
        if (!componentName) {
            // Hide state section if ODE is deselected
            if (componentType === 'ode') {
                this.components.ode.state.section.style.display = 'none';
                this.components.ode.arguments.apply.disabled = true;
                this.fieldValidations.ode.variables = {t: false};
                this.fieldValidations.ode.parameters = {};
            }
            section.style.display = 'none'; // Hide the section
            this.selectedComponents[componentType] = null;
            this.fieldValidations[componentType].args = {};
            this.checkIfRunReady();
            return;
        }
        section.style.display = 'block'; // Show the section

        const fields = this.components[componentType].arguments.fields.section;
        const id = fields.id;
        fields.innerHTML = '';
        
        const componentConfigJson = {
            [componentType]: {
                [componentName]: {
                    args: {}
                }
            }
        }
        this.selectedComponents[componentType] = componentName;
        this.componentConfigs = this.mergeJsons(componentConfigJson, this.componentConfigs);
        this.fieldValidations[componentType].args = {};

        const argValues = this.componentConfigs[componentType][componentName].args;
        const argValidations = this.fieldValidations[componentType].args;
        
        try {
            const argumentTypes = await this.fetchAPI(`/api/get-${componentType}-arguments/${componentName}`);
            argumentTypes.forEach(({name: argName, type: argType}) => {
                const fieldDiv = document.createElement('div');
                fieldDiv.className = 'argument-field';
                
                const label = document.createElement('label');
                label.textContent = argName;
                label.setAttribute('for', `${id}-${argName}`);
                
                const input = document.createElement('input');
                input.type = 'text';
                input.className = 'argument-input';
                input.id = `${id}-${argName}`;
                input.name = `${id}-${argName}`;
                if (!argValues[argName]) {
                    argValues[argName] = ''
                }
                input.addEventListener('input', (e) => {
                    argValues[argName] = e.target.value;
                    argValidations[argName] = this.isValidField(e.target.value, argType);
                    if (argValidations[argName]) {
                        input.classList.remove('invalid');
                    } else {
                        input.classList.add('invalid');
                    }
                    if (componentType === 'ode') {
                        const hasInvalidArgs = Object.values(argValidations).some(arg => !arg);
                        this.components.ode.state.section.style.display = 'none';
                        this.components.ode.arguments.apply.disabled = hasInvalidArgs;
                        this.fieldValidations.ode.variables = {t: false};
                        this.fieldValidations.ode.parameters = {};
                    } else {
                        this.checkIfRunReady();
                    }
                });

                input.value = argValues[argName];
                input.dispatchEvent(new Event('input', { bubbles: true })); // Trigger input event to update UI
                
                const typeInfo = document.createElement('div');
                typeInfo.className = 'argument-type';
                typeInfo.textContent = `Type: ${argType}`;
                
                fieldDiv.appendChild(label);
                fieldDiv.appendChild(input);
                fieldDiv.appendChild(typeInfo);
                fields.appendChild(fieldDiv);
            });
        } catch (error) {
            console.error(`Error loading ${componentType} arguments:`, error);
            this.createPopUp(`Error loading ${componentType} arguments: ${error}`, false);
        }
    }

    async generateStateFields(){
        const section = this.components.ode.state.section;
        const variables = this.components.ode.state.variables;
        const parameters = this.components.ode.state.parameters;
        const hasInvalidArgs = Object.values(this.fieldValidations.ode.args).some(arg => !arg);

        if (hasInvalidArgs) {
            section.style.display = 'none';
            return;
        }

        section.style.display = 'block';
        variables.innerHTML = '';
        parameters.innerHTML = '';
        
        try {
            const odeArgs = {};
            Object.entries(this.componentConfigs.ode[this.selectedComponents.ode].args).forEach(([key, value]) => {
                odeArgs[key] = value;
            });
            
            const stateData = await this.fetchAPI(`/api/get-ode-state/${this.selectedComponents.ode}`, {
                method: 'POST',
                body: odeArgs
            });
            
            // Generate variable fields
            if (stateData.variables) {
                stateData.variables.forEach(({name: varName}) => {
                    this.createStateField('variables', varName, '0');
                });
            }
            
            // Generate parameter fields
            if (stateData.parameters) {
                stateData.parameters.forEach(({name: paramName}) => {
                    this.createStateField('parameters', paramName, '0');
                });
            }
        } catch (error) {
            console.error('Error loading ODE state:', error);
            this.createPopUp(`Error loading ODE state: ${error}`, false);
        }
    }

    createStateField(fieldType, fieldName, fieldValue) {
        const container = this.components.ode.state[fieldType];
        
        const fieldDiv = document.createElement('div');
        fieldDiv.className = 'state-field';
        
        const label = document.createElement('label');
        label.textContent = fieldName;
        label.setAttribute('for', `${container.id}-${fieldName}`);
        
        const input = document.createElement('input');
        input.type = 'text';
        input.className = 'state-input';
        input.id = `${container.id}-${fieldName}`;
        input.name = `${container.id}-${fieldName}`;
        
        // Initialize state config for this field
        const odeJson = {
            [this.selectedComponents.ode]: {
                [fieldType]: {
                    [fieldName]: fieldValue
                }
            }
        }
        this.componentConfigs.ode = this.mergeJsons(odeJson, this.componentConfigs.ode);
        
        const stateValues = this.componentConfigs.ode[this.selectedComponents.ode][fieldType];
        const stateValidations = this.fieldValidations.ode[fieldType];
        
        // Add input event listener
        input.addEventListener('input', (e) => {
            stateValues[fieldName] = e.target.value;
            stateValidations[fieldName] = this.isValidField(e.target.value, 'float');
            if (stateValidations[fieldName]) {
                input.classList.remove('invalid');
            } else {
                input.classList.add('invalid');
            }
            this.checkIfRunReady();
        });
        
        input.value = stateValues[fieldName];
        input.dispatchEvent(new Event('input', { bubbles: true })); // Trigger input event to update UI
        
        const typeInfo = document.createElement('div');
        typeInfo.className = 'state-type';
        typeInfo.textContent = 'Type: float';
        
        fieldDiv.appendChild(label);
        fieldDiv.appendChild(input);
        fieldDiv.appendChild(typeInfo);
        container.appendChild(fieldDiv);
    }

    checkIfRunReady() {
        const isAllSelected = Object.values(this.selectedComponents).every(component => component !== null);
        if (!isAllSelected) {
            this.components.run.button.disabled = true;
            return;
        }
        const isOdeArgsValid = Object.values(this.fieldValidations.ode.args).every(arg => arg);
        const isOdeVariablesValid = Object.values(this.fieldValidations.ode.variables).every(arg => arg);
        const isOdeParametersValid = Object.values(this.fieldValidations.ode.parameters).every(arg => arg);
        const isSolverArgsValid = Object.values(this.fieldValidations.solver.args).every(arg => arg);
        const isJobArgsValid = Object.values(this.fieldValidations.job.args).every(arg => arg);
        if (isOdeArgsValid && isOdeVariablesValid && isOdeParametersValid
            && isSolverArgsValid && isJobArgsValid) {
            this.components.run.button.disabled = false;
        } else {
            this.components.run.button.disabled = true;
        }
    }

    runJob() {
        const odeArgs = this.componentConfigs.ode[this.selectedComponents.ode].args;
        const odeVariables = this.componentConfigs.ode[this.selectedComponents.ode].variables;
        const odeParameters = this.componentConfigs.ode[this.selectedComponents.ode].parameters;
        const solverArgs = this.componentConfigs.solver[this.selectedComponents.solver].args;
        const jobArgs = this.componentConfigs.job[this.selectedComponents.job].args;
        this.components.run.button.disabled = true;
        this.showLoading(true);
        this.fetchAPI(`/api/run-job/${this.selectedComponents.ode}/${this.selectedComponents.solver}/${this.selectedComponents.job}`, {
            method: 'POST',
            body: {
                ode: odeArgs,
                variables: odeVariables,
                parameters: odeParameters,
                solver: solverArgs,
                job: jobArgs
            }
        })
        .then(response => {
            this.createPopUp('Job completed successfully', true);
        })
        .catch(error => {
            console.error('Error running job:', error);
            this.createPopUp(`Error running job: ${error}`, false);
        })
        .finally(() => {
            this.components.run.button.disabled = false;
            this.showLoading(false);
        });
    }

    startProgressTracking(jobId) {
        // Close any existing event source
        if (this.eventSource) {
            this.eventSource.close();
        }

        this.eventSource = new EventSource(`/api/progress/${jobId}`);
        
        this.eventSource.onmessage = (event) => {
            try {
                const progress = JSON.parse(event.data);
                this.updateProgress(progress);
                
                if (progress.status === 'completed') {
                    this.createPopUp('Job completed successfully!', true);
                    this.resetJobState();
                } else if (progress.status === 'error') {
                    this.createPopUp(`Job failed: ${progress.message}`, false);
                    this.resetJobState();
                }
            } catch (e) {
                console.error('Error parsing progress data:', e);
            }
        };
        
        this.eventSource.onerror = (event) => {
            console.error('EventSource failed:', event);
            this.createPopUp('Connection to server lost', false);
            this.resetJobState();
        };
    }

    updateProgress(progress) {
        const percentage = Math.round((progress.current / progress.total) * 100);
        
        this.components.progress.fill.style.width = `${percentage}%`;
        this.components.progress.percentage.textContent = `${percentage}%`;
        this.components.progress.message.textContent = progress.message || 'Processing...';
    }

    showProgress(show) {
        if (show) {
            this.components.progress.section.style.display = 'block';
            this.updateProgress({ current: 0, total: 100, message: 'Starting...' });
        } else {
            this.components.progress.section.style.display = 'none';
        }
    }

    runMockJob() {
        this.fetchAPI('/api/run-job-mock', {
            method: 'POST',
            body: {}
        })
        .then(response => {
            if (response.status === 'started' && response.job_id) {
                this.currentJobId = response.job_id;
                this.startProgressTracking(response.job_id);
            } else {
                throw new Error('Failed to start mock job');
            }
        })
        .catch(error => {
            console.error('Error starting mock job:', error);
            this.createPopUp(`Error starting mock job: ${error}`, false);
            this.resetMockJobState();
        });
    }

    resetJobState() {
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
        }
        
        this.currentJobId = null;
    }

    resetMockJobState() {
        this.resetJobState();
    }
    
    isValidField(argValue, argType) {
        const value = String(argValue).trim();
        
        if (value === '') {
            return false;
        }
        
        switch (argType) {
            case 'int':
                // Check if entire string is a valid integer
                if(/^-?\d+$/.test(value) && !isNaN(parseInt(value, 10))){
                    return true;
                } else {
                    return false;
                }
            case 'float':
                // Check if entire string is a valid float
                if(/^-?\d*\.?\d+([eE][+-]?\d+)?$/.test(value) && !isNaN(parseFloat(value))){
                    return true;
                } else {
                    return false;
                }
            case 'str':
                if(value !== ''){
                    return true;
                } else {
                    return false;
                }
            default:
                return false;
        }
    }

    mergeJsons(obj1, obj2) {
        const result = typeof obj1 === 'object' ? { ...obj1 } : {};
        if (typeof obj2 !== 'object') {
            return result;
        }
        for (const key in obj2) {
            if (
                obj2[key] && typeof obj2[key] === 'object' && !Array.isArray(obj2[key])
                && obj1[key] && typeof obj1[key] === 'object' && !Array.isArray(obj1[key])
            ){
                result[key] = this.mergeJsons(result[key], obj2[key]);
            } else {
                result[key] = obj2[key];
            }
        }
        return result;
    }

    createPopUp(message, isSuccess = true) {
        const type = isSuccess ? 'success' : 'error';
        
        // Remove existing popups FIRST
        const existingPopUps = document.querySelectorAll(`.${type}`);
        existingPopUps.forEach(popup => {
            popup.classList.add('fade-out');
            setTimeout(() => popup.remove(), 300);
        });

        // Create and add new popup AFTER cleaning up existing ones
        const popUp = document.createElement('div');
        popUp.className = `${type}`;
        popUp.textContent = message;
        document.body.appendChild(popUp);

        // Auto-remove after 5 seconds with fade-out animation
        setTimeout(() => {
            if (popUp.parentNode) {
                popUp.classList.add('fade-out');
                setTimeout(() => {
                    if (popUp.parentNode) {
                        popUp.parentNode.removeChild(popUp);
                    }
                }, 300);
            }
        }, 5000);
    }
    
    showLoading(show) {
        const container = document.querySelector('.container');
        if (show) {
            container.classList.add('loading');
        } else {
            container.classList.remove('loading');
        }
    }
}

// Initialize the application when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new DynamicalSystemsUI();
});
