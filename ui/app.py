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
import traceback
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
        res = {
            k: v.__name__ if hasattr(v, '__name__') else v
            for k, v in odes[name].get_argument_types().items()
        }
        return jsonify(res)
    except KeyError:
        return jsonify({}), 404

@app.route('/api/get-solver-arguments/<name>', methods=['GET'])
def get_solver_arguments(name):
    try:
        res = {
            k: v.__name__ if hasattr(v, '__name__') else v
            for k, v in solvers[name].get_argument_types().items()
        }
        return jsonify(res)
    except KeyError:
        return jsonify({}), 404
    
@app.route('/api/get-job-arguments/<name>', methods=['GET'])
def get_job_arguments(name):
    try:
        res = {
            k: v.__name__ if hasattr(v, '__name__') else v
            for k, v in jobs[name].get_argument_types().items()
            if k not in ['ode', 'solver']
        }
        return jsonify(res)
    except KeyError:
        return jsonify({}), 404

@app.route('/api/get-ode-state/<name>', methods=['POST'])
def get_ode_state(name):
    try:
        data = request.get_json()
        ode = odes[name].create(**data)
        res = {
            'state': {
                't': ode.get_t(),
                **{
                    f'x[{i}]': ode.get_x(i)
                    for i in range(ode.get_x_size())
                }
            },
            'parameters': {
                f'p[{i}]': ode.get_p(i)
                for i in range(ode.get_p_size())
            }
        }
        return jsonify(res)
    except KeyError:
        return jsonify({}), 404
    
@app.route('/api/run-job/<ode_name>/<solver_name>/<job_name>', methods=['POST'])
def run_job(ode_name, solver_name, job_name):
    try:
        data = request.get_json()
        ode_args = data['ode']
        solver_args = data['solver']
        job_args = data['job']
        ode = odes[ode_name].create(**ode_args)
        solver = solvers[solver_name].create(**solver_args)
        job = jobs[job_name].create(**job_args)
        job_args['ode'] = ode
        job_args['solver'] = solver
        job.run(**job_args)
        return jsonify({'status': 'success'})
    except KeyError:
        return jsonify({}), 404

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