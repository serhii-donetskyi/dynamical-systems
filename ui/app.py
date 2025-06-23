#!/usr/bin/env python3
"""
Web-based UI for Dynamical Systems
A Flask web application for running dynamical systems simulations.
"""

from flask import Flask, render_template, request, jsonify, send_from_directory, Response
from flask_cors import CORS
import os
import sys
import json
from typing import Dict, Any, Optional, List

# Add the project root to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from dynamical_systems import OdeFactory, Ode, SolverFactory, Solver, Job


app = Flask(__name__)
CORS(app)
app.secret_key = 'dynamical-systems-ui-key'

odes = {}
solvers = {}
jobs = {}

def scan_components():
    project_dir = os.path.join(os.path.dirname(__file__), '..')
    build_dir = os.path.join(project_dir, 'build')
    ode_dir = os.path.join(build_dir, 'ode')
    solver_dir = os.path.join(build_dir, 'solver')
    job_dir = os.path.join(build_dir, 'job')
    
    for file in os.listdir(ode_dir):
        if file.endswith('.so'):
            ode_name = file[:-3]
            full_path = os.path.join(ode_dir, file)
            odes[ode_name] = OdeFactory(full_path)
    
    for file in os.listdir(solver_dir):
        if file.endswith('.so'):
            solver_name = file[:-3]
            full_path = os.path.join(solver_dir, file)
            solvers[solver_name] = SolverFactory(full_path)

    for file in os.listdir(job_dir):
        if file.endswith('.so'):
            job_name = file[:-3]
            full_path = os.path.join(job_dir, file)
            jobs[job_name] = Job(full_path)

@app.route('/')
def index():
    """Main page."""
    return render_template('index.html')

@app.route('/api/get-odes', methods=['GET'])
def get_odes():
    return jsonify(list(odes))

@app.route('/api/get-solvers', methods=['GET'])
def get_solvers():
    return jsonify(list(solvers))

@app.route('/api/get-jobs', methods=['GET'])
def get_jobs():
    return jsonify(list(jobs))

@app.route('/api/get-ode-arguments/<name>', methods=['GET'])
def get_ode_arguments(name):
    try:
        res = [
            {
                'name': k,
                'type': v.__name__ if hasattr(v, '__name__') else v
            }
            for k, v in odes[name].get_argument_types().items()
        ]
        return jsonify(res)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/get-solver-arguments/<name>', methods=['GET'])
def get_solver_arguments(name):
    try:
        res = [
            {
                'name': k,
                'type': v.__name__ if hasattr(v, '__name__') else v
            }
            for k, v in solvers[name].get_argument_types().items()
        ]
        return jsonify(res)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/get-job-arguments/<name>', methods=['GET'])
def get_job_arguments(name):
    try:
        res = [
            {
                'name': k,
                'type': v.__name__ if hasattr(v, '__name__') else v
            }
            for k, v in jobs[name].get_argument_types().items()
            if k not in ['ode', 'solver']
        ]
        return jsonify(res)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/get-ode-state/<name>', methods=['POST'])
def get_ode_state(name):
    try:
        data = request.get_json()
        for arg, tp in odes[name].get_argument_types().items():
            if arg in data:
                data[arg] = tp(data[arg])
        ode = odes[name].create(**data)
        res = {
            'variables': [
                {'name': 't'},
                *[{'name': f'x[{i}]'} for i in range(ode.get_x_size())]
            ],
            'parameters': [{'name': f'p[{i}]'} for i in range(ode.get_p_size())]
        }
        return jsonify(res)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/run-job/<ode_name>/<solver_name>/<job_name>', methods=['POST'])
def run_job(ode_name, solver_name, job_name):
    try:
        data = request.get_json()
        ode_args = data['ode']
        solver_args = data['solver']
        job_args = data['job']
        variables = data['variables']
        parameters = data['parameters']

        ode_types = odes[ode_name].get_argument_types()
        solver_types = solvers[solver_name].get_argument_types()
        job_types = jobs[job_name].get_argument_types()

        ode_kwargs = {}
        solver_kwargs = {}
        job_kwargs = {}
        for arg, tp in ode_types.items():
            ode_kwargs[arg] = tp(ode_args[arg])
        for arg, tp in solver_types.items():
            solver_kwargs[arg] = tp(solver_args[arg])
        for arg, tp in job_types.items():
            if arg in ['ode', 'solver']:
                continue
            job_kwargs[arg] = tp(job_args[arg])

        ode = odes[ode_name].create(**ode_kwargs)
        solver = solvers[solver_name].create(**solver_kwargs)
        job = jobs[job_name]

        ode.set_t(float(variables['t']))
        for i in range(ode.get_x_size()):
            ode.set_x(i, float(variables[f'x[{i}]']))
        for i in range(ode.get_p_size()):
            ode.set_p(i, float(parameters[f'p[{i}]']))

        job_kwargs['ode'] = ode
        job_kwargs['solver'] = solver
        job.run(**job_kwargs)
        return jsonify({'status': 'success'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting Dynamical Systems Web UI...")
    print("Scanning for components...")
    scan_components()
    print("Available components:")
    print(f"  ODEs: {list(odes)}")
    print(f"  Solvers: {list(solvers)}")
    print(f"  Jobs: {list(jobs)}")
    print("\nAccess the application at: http://localhost:5001")
    
    app.run(debug=True, host='0.0.0.0', port=5001)