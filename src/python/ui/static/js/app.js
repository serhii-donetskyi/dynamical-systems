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
            container: document.getElementById('container'),
            ode: {
                dropdown: document.getElementById('ode-dropdown-select'),
                arguments: {
                    section: document.getElementById('ode-arguments'),
                    fields: document.getElementById('ode-arguments-fields'),
                    apply: document.getElementById('ode-arguments-apply-btn')
                },
                state: {
                    section: document.getElementById('ode-state'),
                    variables: document.getElementById('ode-state-content-variables'),
                    parameters: document.getElementById('ode-state-content-parameters')
                }
            },
            solver: {
                dropdown: document.getElementById('solver-dropdown-select'),
                arguments: {
                    section: document.getElementById('solver-arguments'),
                    fields: document.getElementById('solver-arguments-fields'),
                }
            },
            job: {
                dropdown: document.getElementById('job-dropdown-select'),
                arguments: {
                    section: document.getElementById('job-arguments'),
                    fields: document.getElementById('job-arguments-fields'),
                }
            },
            action: {
                section: document.getElementById('action-section'),
                run: document.getElementById('action-section-run-btn'),
                cancel: document.getElementById('action-section-cancel-btn'),
                save: document.getElementById('action-section-save-config-btn'),
                load: document.getElementById('action-section-load-config-btn'),
            },
            progress: {
                section: document.getElementById('progress-section'),
                fill: document.getElementById('progress-section-fill'),
                percentage: document.getElementById('progress-section-percentage'),
                message: document.getElementById('progress-section-message')
            }
        }

        this.jobId = null;
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
            this.createPopUp(`Failed to load components: ${error}`, false);
        }

        // Dropdown change listeners
        this.components.ode.dropdown.addEventListener('change', (e) => {
            this.generateArgumentFields('ode', e.target.value);
        });

        this.components.solver.dropdown.addEventListener('change', (e) => {
            this.generateArgumentFields('solver', e.target.value);
        });

        this.components.job.dropdown.addEventListener('change', (e) => {
            this.generateArgumentFields('job', e.target.value);
        });

        this.components.ode.arguments.apply.addEventListener('click', () => {
            this.generateStateFields();
        });

        this.components.action.run.addEventListener('click', () => {
            this.runJob();
        });

        this.components.action.cancel.addEventListener('click', () => {
            this.cancelJob();
        });

        this.components.action.save.addEventListener('click', () => {
            this.saveConfig();
        });

        this.components.action.load.addEventListener('click', () => {
            this.loadConfig();
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
        const dropdown = this.components[componentType].dropdown;
        while (dropdown.children.length > 1) {
            dropdown.removeChild(dropdown.lastChild);
        }
        options.forEach(option => {
            const optionElement = document.createElement('option');
            optionElement.value = option;
            optionElement.textContent = option;
            dropdown.appendChild(optionElement);
        });
    }

    async generateArgumentFields(componentType, componentName) {
        const section = this.components[componentType].arguments.section;
        if (!componentName) {
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
        if (!(componentName in this.componentConfigs[componentType])) {
            this.componentConfigs[componentType][componentName] = {};
            this.componentConfigs[componentType][componentName].args = {};
            if (componentType === 'ode') {
                this.componentConfigs.ode[componentName].variables = {};
                this.componentConfigs.ode[componentName].parameters = {};
            }
        }
        section.style.display = 'block'; // Show the section
        this.selectedComponents[componentType] = componentName;
        this.components[componentType].arguments.fields.innerHTML = '';

        try {
            const argumentTypes = await this.fetchAPI(`/api/get-${componentType}-arguments/${componentName}`);
            if (argumentTypes.length === 0) {
                await this.generateStateFields();
                return;
            }
            argumentTypes.forEach(({name: argName, type: argType}) => {
                this.createArgumentField(componentType, argName, argType);
            });
        } catch (error) {
            this.createPopUp(`Error loading ${componentType} arguments: ${error}`, false);
        }
    }

    async createArgumentField(componentType, argName, argType) {
        const argValues = this.componentConfigs[componentType][this.selectedComponents[componentType]].args;
        const argValidations = this.fieldValidations[componentType].args;

        const fields = this.components[componentType].arguments.fields;
        const id = fields.id;

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
    }

    async generateStateFields(){
        this.components.ode.arguments.apply.disabled = true;
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
            const stateData = await this.fetchAPI(`/api/get-ode-state/${this.selectedComponents.ode}`, {
                method: 'POST',
                body: this.componentConfigs.ode[this.selectedComponents.ode].args
            });

            // Generate variable fields
            if (stateData.variables) {
                stateData.variables.forEach(({name: varName}) => {
                    this.createStateField('variables', varName);
                });
            }

            // Generate parameter fields
            if (stateData.parameters) {
                stateData.parameters.forEach(({name: paramName}) => {
                    this.createStateField('parameters', paramName);
                });
            }
        } catch (error) {
            this.createPopUp(`Error loading ODE state: ${error}`, false);
        }
    }

    createStateField(fieldType, fieldName) {
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

        input.value = stateValues[fieldName] || '0';
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
            this.components.action.run.disabled = true;
            return;
        }
        const isOdeArgsValid = Object.values(this.fieldValidations.ode.args).every(arg => arg);
        const isOdeVariablesValid = Object.values(this.fieldValidations.ode.variables).every(arg => arg);
        const isOdeParametersValid = Object.values(this.fieldValidations.ode.parameters).every(arg => arg);
        const isSolverArgsValid = Object.values(this.fieldValidations.solver.args).every(arg => arg);
        const isJobArgsValid = Object.values(this.fieldValidations.job.args).every(arg => arg);
        if (isOdeArgsValid && isOdeVariablesValid && isOdeParametersValid
            && isSolverArgsValid && isJobArgsValid) {
            this.components.action.run.disabled = false;
        } else {
            this.components.action.run.disabled = true;
        }
    }

    runJob() {
        this.setLoading(true);
        this.fetchAPI(`/api/run-job/${this.selectedComponents.ode}/${this.selectedComponents.solver}/${this.selectedComponents.job}`, {
            method: 'POST',
            body: {
                ode: this.componentConfigs.ode[this.selectedComponents.ode],
                solver: this.componentConfigs.solver[this.selectedComponents.solver],
                job: this.componentConfigs.job[this.selectedComponents.job]
            }
        })
        .then(response => {
            if (response.status !== 'started' || !response.job_id) {
                throw new Error('Failed to start mock job');
            }

            this.jobId = response.job_id;
            // Close any existing event source
            if (this.eventSource) {
                this.eventSource.close();
            }

            this.eventSource = new EventSource(`/api/job-event-stream/${this.jobId}`);

            this.eventSource.onmessage = (event) => {
                try {
                    const eventData = JSON.parse(event.data);
                    const percentage = parseInt(eventData.progress);

                    this.components.progress.fill.style.width = `${percentage}%`;
                    this.components.progress.percentage.textContent = `${percentage}%`;
                    this.components.progress.message.textContent = eventData.message;

                    if (eventData.status === 'completed') {
                        this.createPopUp(eventData.message, true);
                        this.resetJobState();
                    } else if (eventData.status === 'error') {
                        this.createPopUp(eventData.message, false);
                        this.resetJobState();
                    }
                } catch (e) {
                    this.createPopUp('Error parsing progress data', false);
                    this.resetJobState();
                }
            };

            this.eventSource.onerror = (event) => {
                this.createPopUp('Connection to server lost', false);
                this.resetJobState();
            };
        })
        .catch(error => {
            this.createPopUp(`${error}`, false);
            this.resetJobState();
        });
    }

    cancelJob() {
        // Close EventSource first to prevent onerror event
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
        }
        this.components.progress.message.textContent = 'Canceled';


        this.fetchAPI(`/api/cancel-job/${this.jobId}`, {
            method: 'POST'
        })
        .then(response => {
            this.createPopUp('Job cancelled', true);
            this.resetJobState();
        })
        .catch(error => {
            this.createPopUp(`Error cancelling job: ${error}`, false);
            this.resetJobState();
        });
    }

    resetJobState() {
        if (this.eventSource) {
            this.eventSource.close();
            this.eventSource = null;
        }
        this.jobId = null;
        this.setLoading(false);
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

    createPopUp(message, isSuccess = true) {
        const type = isSuccess ? 'success' : 'error';

        if (isSuccess) {
            console.log(message);
        } else {
            console.error(message);
        }

        // Remove existing popups FIRST
        const existingPopUps = document.querySelectorAll('#pop-up');
        existingPopUps.forEach(popup => {
            popup.classList.add('fade-out');
            setTimeout(() => popup.remove(), 300);
        });

        // Create and add new popup AFTER cleaning up existing ones
        const popUp = document.createElement('div');
        popUp.className = `${type}`;
        popUp.textContent = message;
        popUp.id = 'pop-up';
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

    setLoading(isLoading) {
        const interactiveElements = [
            this.components.action.run,
            this.components.ode.dropdown,
            this.components.solver.dropdown,
            this.components.job.dropdown,
            this.components.action.save,
            this.components.action.load,
            ...this.components.ode.arguments.fields.querySelectorAll('input'),
            ...this.components.solver.arguments.fields.querySelectorAll('input'),
            ...this.components.job.arguments.fields.querySelectorAll('input'),
            ...this.components.ode.state.variables.querySelectorAll('input'),
            ...this.components.ode.state.parameters.querySelectorAll('input'),
        ]
        if (isLoading) {
            this.components.container.classList.add('loading');
            this.components.action.cancel.disabled = false;
            this.components.progress.fill.classList.remove('no-animation');
            interactiveElements.forEach(element => {
                element.disabled = true;
            });
        } else {
            this.components.container.classList.remove('loading');
            this.components.action.cancel.disabled = true;
            this.components.progress.fill.classList.add('no-animation');
            interactiveElements.forEach(element => {
                element.disabled = false;
            });
        }
    }

    saveConfig() {
        try {
            // Create configuration object
            const config = {
                selectedComponents: this.selectedComponents,
                componentConfigs: this.componentConfigs
            };

            // Convert to JSON string with pretty formatting
            const configJSON = JSON.stringify(config, null, 2);

            // Create filename with timestamp
            const filename = `dynamical-systems-config.json`;

            // Download the file
            this.downloadFile(filename, configJSON);

            this.createPopUp('Configuration saved successfully!', true);
        } catch (error) {
            console.error('Save config error:', error);
            this.createPopUp(`Failed to save configuration: ${error.message}`, false);
        }
    }

    loadConfig() {
        // Create file input element
        const fileInput = document.createElement('input');
        fileInput.type = 'file';
        fileInput.accept = '.json';
        fileInput.style.display = 'none';

        fileInput.addEventListener('change', (e) => {
            const file = e.target.files[0];
            if (!file) return;

            const reader = new FileReader();
            reader.onload = (e) => {
                try {
                    const config = JSON.parse(e.target.result);
                    this.applyConfig(config);
                    this.createPopUp('Configuration loaded successfully!', true);
                } catch (error) {
                    console.error('Load config error:', error);
                    this.createPopUp(`Failed to load configuration: ${error.message}`, false);
                }
            };
            reader.readAsText(file);

            // Clean up
            document.body.removeChild(fileInput);
        });

        // Trigger file dialog
        document.body.appendChild(fileInput);
        fileInput.click();
    }

    applyConfig(config) {
        try {
            // Validate config structure
            if (!config.selectedComponents || !config.componentConfigs) {
                throw new Error('Invalid configuration file format');
            }

            // Store the loaded config
            this.componentConfigs = config.componentConfigs || {};
            this.selectedComponents = config.selectedComponents || { ode: null, solver: null, job: null };

            // Restore UI state
            this.restoreUIState();

        } catch (error) {
            throw new Error(`Configuration apply failed: ${error.message}`);
        }
    }

    async restoreUIState() {
        try {
            // Restore dropdown selections and wait for async operations to complete
            const restorePromises = Object.keys(this.selectedComponents).map(async (componentType) => {
                const selectedValue = this.selectedComponents[componentType];
                if (selectedValue) {
                    const dropdown = this.components[componentType].dropdown;
                    dropdown.value = selectedValue;

                    // Generate argument fields and wait for completion
                    await this.generateArgumentFields(componentType, selectedValue);
                }
            });

            // Wait for all dropdown restorations to complete
            await Promise.all(restorePromises);

            // Now restore ODE state fields if needed
            if (this.selectedComponents.ode) {
                await this.generateStateFields();
            }

            this.checkIfRunReady();

        } catch (error) {
            console.error('UI restore error:', error);
            this.createPopUp(`Failed to restore UI state: ${error.message}`, false);
        }
    }

    downloadFile(filename, fileContent) {
        try {
            const blob = new Blob([fileContent], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            return true;
        } catch (error) {
            console.error('Download file error:', error);
            throw error;
        }
    }
}

// Initialize the application when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new DynamicalSystemsUI();
});
