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
            }
        }
        
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
            this.showError(`Failed to load components: ${error}`);
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
    }
    
    async fetchAPI(url) {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    }

    populateDropdown(componentType, options) {
        const select = this.components[componentType].dropdown.select;
        while (select.children.length > 1) {
            select.removeChild(select.lastChild);
        }
        options.forEach(option => {
            console.log(option);
            const optionElement = document.createElement('option');
            optionElement.value = option;
            optionElement.textContent = option;
            select.appendChild(optionElement);
        });
    }

    async generateArgumentFields(componentType, componentName) {
        const section = this.components[componentType].arguments.section;
        if (!componentName) {
            this.selectedComponents[componentType] = null;
            section.style.display = 'none'; // Hide the section
            return;
        }
        section.style.display = 'block'; // Show the section

        const fields = this.components[componentType].arguments.fields.section;
        const id = fields.id;
        fields.innerHTML = '';
        
        this.selectedComponents[componentType] = componentName;
        if (!this.componentConfigs[componentType][componentName]) {
            this.componentConfigs[componentType][componentName] = {args: {}};
        }
        const args = this.componentConfigs[componentType][componentName].args;
        
        try {
            const argumentTypes = await this.fetchAPI(`/api/get-${componentType}-arguments/${componentName}`);
            
            Object.entries(argumentTypes).forEach(([argName, argType]) => {
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
                if (!args[argName]) {
                    args[argName] = {
                        value: '',
                        isValid: false
                    };
                }
                const arg = args[argName];
                input.addEventListener('input', (e) => {
                    arg.value = e.target.value;
                    arg.isValid = this.isValidArgument(e.target.value, argType);
                    if (arg.isValid) {
                        input.classList.remove('invalid');
                    } else {
                        input.classList.add('invalid');
                    }
                });

                input.value = arg.value;
                arg.isValid = this.isValidArgument(arg.value, argType);
                if (arg.isValid) {
                    input.classList.remove('invalid');
                } else {
                    input.classList.add('invalid');
                }
                
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
            this.showError(`Failed to load ${componentType} arguments for ${componentName}`);
        }
    }
    
    isValidArgument(argValue, argType) {
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

    validateComponentArguments(componentType, componentName) {
        const args = this.componentConfigs[componentType][componentName].args;
        
        // Check if any arguments are invalid
        const hasInvalidArgs = Object.values(args).some(arg => !arg.isValid);
        
        if (hasInvalidArgs) {
            this.components[componentType].arguments.section.classList.add('invalid');
        } else {
            this.components[componentType].arguments.section.classList.remove('invalid');
        }
    }
    
    showResults(content) {
        const resultsSection = document.getElementById('results-section');
        const resultsContent = document.getElementById('results-content');
        
        if (typeof content === 'string') {
            resultsContent.innerHTML = content;
        } else {
            resultsContent.innerHTML = '';
            resultsContent.appendChild(content);
        }
        
        resultsSection.style.display = 'block';
    }
    
    showError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error';
        errorDiv.textContent = message;
        
        // Remove existing error messages
        const existingErrors = document.querySelectorAll('.error');
        existingErrors.forEach(error => error.remove());
        
        // Add new error message
        document.querySelector('.form-section').appendChild(errorDiv);
        
        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (errorDiv.parentNode) {
                errorDiv.parentNode.removeChild(errorDiv);
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