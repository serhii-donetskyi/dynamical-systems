import * as THREE from './three.module.js';

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

class Plot3D {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0xffffff);

        this.camera = new THREE.PerspectiveCamera(75, this.container.clientWidth / this.container.clientHeight, 0.1, 1000);
        this.renderer = new THREE.WebGLRenderer({
            canvas: document.getElementById('canvas'),
            antialias: true
        });

        this.renderer.setSize(1080, 720, false);  // false means don't update style
        this.renderer.setClearColor(0xffffff);

        // Set camera position
        this.camera.position.set(5, 5, 5);
        this.camera.lookAtPosition = new THREE.Vector3(0, 0, 0);
        this.camera.lookAt(this.camera.lookAtPosition);

        // Add orbit controls (mouse interaction)
        this.setupControls();

        // Handle window resize
        window.addEventListener('resize', () => this.onWindowResize());

        this.animate();
    }

    setupControls() {
        // Basic mouse controls for camera rotation
        let isMouseDown = false;
        let mouseX = 0, mouseY = 0;

        this.renderer.domElement.addEventListener('mousedown', (e) => {
            isMouseDown = true;
            mouseX = e.clientX;
            mouseY = e.clientY;
        });

        this.renderer.domElement.addEventListener('mouseup', () => {
            isMouseDown = false;
        });

        this.renderer.domElement.addEventListener('mousemove', (e) => {
            if (!isMouseDown) return;

            const deltaX = e.clientX - mouseX;
            const deltaY = e.clientY - mouseY;

            const spherical = new THREE.Spherical();
            spherical.setFromVector3(this.camera.position.clone().sub(this.camera.lookAtPosition));
            spherical.theta -= deltaX * 0.01;
            spherical.phi += deltaY * 0.01;
            spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, spherical.phi));

            this.camera.position.setFromSpherical(spherical).add(this.camera.lookAtPosition);
            this.camera.lookAt(this.camera.lookAtPosition);
            console.log(this.camera.position.length());
            console.log(this.camera.position.clone().sub(this.camera.lookAtPosition).length());

            mouseX = e.clientX;
            mouseY = e.clientY;
        });

        // Zoom with mouse wheel
        this.renderer.domElement.addEventListener('wheel', (e) => {
            const scale = e.deltaY > 0 ? 1.1 : 0.9;
            this.camera.position.sub(this.camera.lookAtPosition).multiplyScalar(scale).add(this.camera.lookAtPosition);
            this.updateTicks(); // Update ticks when zooming
        });
    }

    plotTrajectory(points) {
        // Clear previous plots
        const existingLine = this.scene.getObjectByName('trajectory');
        if (existingLine) this.scene.remove(existingLine);

        // Create trajectory line
        const geometry = new THREE.BufferGeometry();
        const positions = new Float32Array(points.length * 3);
        let maxX = points[0][0];
        let minX = points[0][0];
        let minY = points[0][1];
        let maxY = points[0][1];
        let minZ = points[0][2] || 0;
        let maxZ = points[0][2] || 0;

        for (let i = 0; i < points.length; i++) {
            const x = points[i][0];
            const y = points[i][1];
            const z = points[i][2] || 0; // Default z=0 for 2D systems
            positions[i * 3] = x;
            positions[i * 3 + 1] = y;
            positions[i * 3 + 2] = z;
            maxX = Math.max(maxX, x);
            minX = Math.min(minX, x);
            maxY = Math.max(maxY, y);
            minY = Math.min(minY, y);
            maxZ = Math.max(maxZ, z);
            minZ = Math.min(minZ, z);
        }

        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));

        const material = new THREE.LineBasicMaterial({ color: 0x0066cc, linewidth: 2 });
        const line = new THREE.Line(geometry, material);
        line.name = 'trajectory';

        this.scene.add(line);
        this.camera.lookAtPosition = new THREE.Vector3((maxX + minX) / 2, (maxY + minY) / 2, (maxZ + minZ) / 2);
        this.camera.lookAt(this.camera.lookAtPosition);

        // Add coordinate axes
        this.addAxes();
    }

    addAxes() {
        // Remove existing axes, ticks, and grid
        const existingAxes = this.scene.getObjectByName('axes');
        if (existingAxes) this.scene.remove(existingAxes);
        const existingTicks = this.scene.getObjectByName('ticks');
        if (existingTicks) this.scene.remove(existingTicks);
        const existingGrid = this.scene.getObjectByName('grid');
        if (existingGrid) this.scene.remove(existingGrid);

        const axesGroup = new THREE.Group();
        axesGroup.name = 'axes';

        // Fixed axis length
        const axisLength = 10;

        // Create grid planes
        const gridGroup = new THREE.Group();
        gridGroup.name = 'grid';

        // Helper function to create a grid plane
        const createGridPlane = (normal, color) => {
            const gridGeometry = new THREE.BufferGeometry();
            const gridLines = [];
            const step = 1; // 1 unit between grid lines
            const range = axisLength;

            // Create grid lines
            for (let i = -range; i <= range; i += step) {
                if (normal === 'xy') {
                    // Lines parallel to x-axis
                    gridLines.push(new THREE.Vector3(-range, i, 0));
                    gridLines.push(new THREE.Vector3(range, i, 0));
                    // Lines parallel to y-axis
                    gridLines.push(new THREE.Vector3(i, -range, 0));
                    gridLines.push(new THREE.Vector3(i, range, 0));
                } else if (normal === 'xz') {
                    // Lines parallel to x-axis
                    gridLines.push(new THREE.Vector3(-range, 0, i));
                    gridLines.push(new THREE.Vector3(range, 0, i));
                    // Lines parallel to z-axis
                    gridLines.push(new THREE.Vector3(i, 0, -range));
                    gridLines.push(new THREE.Vector3(i, 0, range));
                } else if (normal === 'yz') {
                    // Lines parallel to y-axis
                    gridLines.push(new THREE.Vector3(0, -range, i));
                    gridLines.push(new THREE.Vector3(0, range, i));
                    // Lines parallel to z-axis
                    gridLines.push(new THREE.Vector3(0, i, -range));
                    gridLines.push(new THREE.Vector3(0, i, range));
                }
            }

            gridGeometry.setFromPoints(gridLines);
            const gridMaterial = new THREE.LineBasicMaterial({
                color: color,
                opacity: 0.1,
                transparent: true
            });
            return new THREE.LineSegments(gridGeometry, gridMaterial);
        };

        // Add grid planes
        gridGroup.add(createGridPlane('xy', 0x666666)); // XY plane
        gridGroup.add(createGridPlane('xz', 0x666666)); // XZ plane
        gridGroup.add(createGridPlane('yz', 0x666666)); // YZ plane

        // X axis (black)
        const xGeometry = new THREE.BufferGeometry().setFromPoints([
            new THREE.Vector3(-axisLength, 0, 0), new THREE.Vector3(axisLength, 0, 0)
        ]);
        const xMaterial = new THREE.LineBasicMaterial({ color: 0x000000 });
        axesGroup.add(new THREE.Line(xGeometry, xMaterial));

        // Y axis (black)
        const yGeometry = new THREE.BufferGeometry().setFromPoints([
            new THREE.Vector3(0, -axisLength, 0), new THREE.Vector3(0, axisLength, 0)
        ]);
        const yMaterial = new THREE.LineBasicMaterial({ color: 0x000000 });
        axesGroup.add(new THREE.Line(yGeometry, yMaterial));

        // Z axis (black)
        const zGeometry = new THREE.BufferGeometry().setFromPoints([
            new THREE.Vector3(0, 0, -axisLength), new THREE.Vector3(0, 0, axisLength)
        ]);
        const zMaterial = new THREE.LineBasicMaterial({ color: 0x000000 });
        axesGroup.add(new THREE.Line(zGeometry, zMaterial));

        this.scene.add(gridGroup);
        this.scene.add(axesGroup);

        // Add dynamic ticks
        this.updateTicks();
    }

    updateTicks() {
        // Remove existing ticks
        const existingTicks = this.scene.getObjectByName('ticks');
        if (existingTicks) this.scene.remove(existingTicks);

        const ticksGroup = new THREE.Group();
        ticksGroup.name = 'ticks';

        // Calculate base scale from camera distance
        const cameraDistance = this.camera.position.length();
        const orderOfMagnitude = Math.floor(Math.log10(cameraDistance));
        const baseTickStep = Math.pow(10, orderOfMagnitude - 1);
        const tickSize = baseTickStep * 0.2;

        // Calculate viewport size at the axes plane
        const vFOV = this.camera.fov * Math.PI / 180;
        const planeDistance = this.camera.position.length();
        const viewHeight = 2 * Math.tan(vFOV / 2) * planeDistance;
        const viewWidth = viewHeight * this.camera.aspect;

        // Calculate minimum space between ticks (in world units)
        const minTickSpacing = viewWidth / 15; // Aim for about 15 ticks across view

        // Helper function to create tick line
        const createTick = (value, axis) => {
            let start, end;
            if (axis === 'x') {
                start = new THREE.Vector3(value, 0, 0);
                end = new THREE.Vector3(value, -tickSize, 0);
            } else if (axis === 'y') {
                start = new THREE.Vector3(0, value, 0);
                end = new THREE.Vector3(tickSize, value, 0);
            } else {
                start = new THREE.Vector3(0, 0, value);
                end = new THREE.Vector3(tickSize, 0, value);
            }

            const geometry = new THREE.BufferGeometry().setFromPoints([start, end]);
            const material = new THREE.LineBasicMaterial({ color: 0x000000 });
            const tick = new THREE.Line(geometry, material);

            // Add tick label with higher resolution
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            canvas.width = 256; // 4x resolution
            canvas.height = 128;
            context.fillStyle = '#000000';
            context.font = '72px Arial'; // Increased font size for higher resolution
            context.textAlign = 'center';
            context.textBaseline = 'middle';

            // Format number based on magnitude
            let label;
            if (Math.abs(value) >= 1000 || Math.abs(value) <= 0.001) {
                label = value.toExponential(1);
            } else {
                label = value.toPrecision(3);
            }
            context.fillText(label, canvas.width/2, canvas.height/2);

            const texture = new THREE.CanvasTexture(canvas);
            const spriteMaterial = new THREE.SpriteMaterial({ map: texture });
            const sprite = new THREE.Sprite(spriteMaterial);

            // Position label based on axis
            const labelOffset = tickSize * 2;
            if (axis === 'x') {
                sprite.position.set(value, -labelOffset, 0);
            } else if (axis === 'y') {
                sprite.position.set(labelOffset, value, 0);
            } else {
                sprite.position.set(labelOffset, 0, value);
            }

            // Scale sprite based on view distance
            const spriteScale = planeDistance * 0.1;
            sprite.scale.set(spriteScale, spriteScale * 0.5, 1);

            ticksGroup.add(tick);
            ticksGroup.add(sprite);
        };

        // Generate tick values based on order of magnitude
        const tickValues = [];
        const range = Math.max(Math.abs(viewWidth), Math.abs(viewHeight)) / 2;
        const step = Math.pow(10, Math.floor(Math.log10(minTickSpacing)));

        // Generate main divisions
        for (let i = -Math.ceil(range/step); i <= Math.ceil(range/step); i++) {
            const value = i * step;
            if (Math.abs(value) > 1e-10) { // Skip very small values near zero
                tickValues.push(value);
            }
        }

        // Add intermediate ticks if space allows
        if (step >= minTickSpacing * 2) {
            for (let i = -Math.ceil(range/step); i <= Math.ceil(range/step); i++) {
                const value = (i + 0.5) * step;
                if (Math.abs(value) > 1e-10) {
                    tickValues.push(value);
                }
            }
        }

        // Sort values
        tickValues.sort((a, b) => a - b);

        // Create ticks for each axis
        tickValues.forEach(value => {
            createTick(value, 'x');
            createTick(value, 'y');
            createTick(value, 'z');
        });

        this.scene.add(ticksGroup);
    }

    onWindowResize() {
        this.camera.aspect = this.container.clientWidth / this.container.clientHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
        this.updateTicks(); // Update ticks when window resizes
    }

    animate() {
        requestAnimationFrame(() => this.animate());
        this.renderer.render(this.scene, this.camera);
    }
}

// Initialize the application when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const ui = new DynamicalSystemsUI();

    // Initialize 3D plot
    ui.plot3D = new Plot3D('plot-container');

    // Example: Plot a simple 3D spiral for demonstration
    const examplePoints = [];
    for (let t = 0; t < 20; t += 0.1) {
        examplePoints.push([
            Math.cos(t) * (1 + t * 0.1),
            Math.sin(t) * (1 + t * 0.1),
            t * 0.2
        ]);
    }
    ui.plot3D.plotTrajectory(examplePoints);
});
