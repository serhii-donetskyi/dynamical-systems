#!/usr/bin/env python3
"""
Web-based UI for Dynamical Systems
A Flask web application for running dynamical systems simulations.
"""

from flask import Flask, render_template, request, jsonify, send_from_directory, Response
from flask_cors import CORS
import json
import time
import sys
import traceback
import subprocess
import uuid

from dynamical_systems import components, generate_module_cmd

app = Flask(__name__)
CORS(app)
app.secret_key = 'dynamical-systems-ui-key'

processes = {}

@app.route('/')
def index():
    """Main page."""
    return render_template('index.html')

@app.route('/api/get-odes', methods=['GET'])
def get_odes():
    return jsonify(list(components['ode']))

@app.route('/api/get-solvers', methods=['GET'])
def get_solvers():
    return jsonify(list(components['solver']))

@app.route('/api/get-jobs', methods=['GET'])
def get_jobs():
    return jsonify(list(components['job']))

@app.route('/api/get-ode-arguments/<name>', methods=['GET'])
def get_ode_arguments(name):
    try:
        return jsonify([
            {
                'name': arg['name'],
                'type': arg['type'].__name__
            }
            for arg in components['ode'][name].get_argument_types()
        ])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/get-solver-arguments/<name>', methods=['GET'])
def get_solver_arguments(name):
    try:
        return jsonify([
            {
                'name': arg['name'],
                'type': arg['type'].__name__
            }
            for arg in components['solver'][name].get_argument_types()
        ])
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/get-job-arguments/<name>', methods=['GET'])
def get_job_arguments(name):
    try:
        return jsonify([
            {
                'name': arg['name'],
                'type': arg['type'].__name__
            }
            for arg in components['job'][name].get_argument_types()
            if arg['name'] not in ['ode', 'solver']
        ])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/get-ode-state/<ode_name>', methods=['POST'])
def get_ode_state(ode_name):
    try:
        data = request.get_json()
        kwargs = {}
        for arg in components['ode'][ode_name].get_argument_types():
            name = arg['name']
            tp = arg['type']
            value = data[name]
            kwargs[name] = tp(value)
        ode = components['ode'][ode_name].create(**kwargs)
        res = {
            'variables': [
                {'name': 't'},
                *[{'name': f'x[{i}]'} for i in range(ode.get_x_size())]
            ],
            'parameters': [{'name': f'p[{i}]'} for i in range(ode.get_p_size())]
        }
        return jsonify(res)
    except Exception as e:
        print(e, file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/run-job/<ode_name>/<solver_name>/<job_name>', methods=['POST'])
def run_job(ode_name, solver_name, job_name):
    try:
        job_id = str(uuid.uuid4())
        data = request.get_json()
        ode_data = data['ode']
        solver_data = data['solver']
        job_data = data['job']

        ode_types = components['ode'][ode_name].get_argument_types()
        solver_types = components['solver'][solver_name].get_argument_types()
        job_types = components['job'][job_name].get_argument_types()

        ode_kwargs = {}
        solver_kwargs = {}
        job_kwargs = {}
        for arg in ode_types:
            name = arg['name']
            tp = arg['type']
            value = ode_data['args'][name]
            ode_kwargs[name] = tp(value)
        for arg in solver_types:
            name = arg['name']
            tp = arg['type']
            value = solver_data['args'][name]
            solver_kwargs[name] = tp(value)
        for arg in job_types:
            name = arg['name']
            tp = arg['type']
            if name in ['ode', 'solver']:
                continue
            value = job_data['args'][name]
            job_kwargs[name] = tp(value)

        ode = components['ode'][ode_name].create(**ode_kwargs)
        ode.set_t(float(ode_data['variables']['t']))
        ode.set_x([float(ode_data['variables'][f'x[{i}]']) for i in range(ode.get_x_size())])
        ode.set_p([float(ode_data['parameters'][f'p[{i}]']) for i in range(ode.get_p_size())])

        solver = components['solver'][solver_name].create(**solver_kwargs)
        job = components['job'][job_name]

        job_kwargs['ode'] = ode
        job_kwargs['solver'] = solver
        
        process = subprocess.Popen(
            generate_module_cmd(job, job_kwargs),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0,  # Unbuffered
            universal_newlines=True
        )
        processes[job_id] = process
        return jsonify({'status': 'started', 'job_id': job_id})
    except Exception as e:
        print(e, file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        return jsonify({'error': str(e)}), 500

@app.route('/api/job-event-stream/<job_id>')
def job_event_stream(job_id):
    def generate():
        status = {
            'progress': 0,
            'status': 'error',
            'message': ''
        }
        if job_id not in processes:
            status['status'] = 'error'
            status['message'] = 'Job not found'
            yield f"data: {json.dumps(status)}\n\n"
            return
        
        process = processes[job_id]

        if not process:
            status['status'] = 'error'
            status['message'] = 'Failed to start process'
            yield f"data: {json.dumps(status)}\n\n"
            return
        try:
            for line in process.stdout:
                progress = int(line.strip())
                if progress > 100:
                    raise ValueError(f"Progress is greater than 100: {progress}")
                status['progress'] = progress
                status['status'] = 'running' if progress < 100 else 'completed'
                status['message'] = f'Processing...' if progress < 100 else 'Job finished'
                yield f"data: {json.dumps(status)}\n\n"
        except Exception as e:
            status['status'] = 'error'
            status['message'] = f'Error: {str(e)}'
            yield f"data: {json.dumps(status)}\n\n"
            print(e, file=sys.stderr)
            print(traceback.format_exc(), file=sys.stderr)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        del processes[job_id]
    
    return Response(
        generate(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Access-Control-Allow-Origin': '*'
        }
    )

if __name__ == '__main__':
    print("Starting Dynamical Systems Web UI...")
    print("Scanning for components...")
    print("Available components:")
    print(f"  ODEs: {list(components['ode'])}")
    print(f"  Solvers: {list(components['solver'])}")
    print(f"  Jobs: {list(components['job'])}")
    print("\nAccess the application at: http://localhost:5001")
    
    app.run(debug=True, host='0.0.0.0', port=5001)
