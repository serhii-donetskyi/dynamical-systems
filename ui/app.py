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
import time
import multiprocessing
import traceback

# Add the project root to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from dynamical_systems import OdeFactory, Ode, SolverFactory, Solver, Job

app = Flask(__name__)
CORS(app)
app.secret_key = 'dynamical-systems-ui-key'

odes = {}
solvers = {}
jobs = {}
processes = {}

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

class JobProcess:
    class AliveAfterEndError(Exception):
        pass
    class TerminatedWithoutEndError(Exception):
        pass

    """Custom stdout that sends lines to queue immediately"""
    def __init__(self, fn, *args, **kwargs):
        self.queue = multiprocessing.Queue()
        self.process = multiprocessing.Process(target=self)
        self.buffer = ""
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
    
    def write(self, text):
        self.buffer += text
        while '\n' in self.buffer:
            line, self.buffer = self.buffer.split('\n', 1)
            if line:
                self.queue.put(line)
        return len(text)
    
    def flush(self):
        line = self.buffer
        if line:
            self.queue.put(line)
        self.buffer = ""

    def start(self):
        self.process.start()

    def join(self, timeout: float | None = None):
        self.process.join(timeout)

    def is_alive(self):
        return self.process.is_alive()

    def terminate(self):
        if self.process.is_alive():
            self.process.terminate()

    def kill(self):
        if self.process.is_alive():
            self.process.kill()

    def get_lines(self):
        def get():
            return self.queue.get(timeout=5)
        def get_nowait():
            return self.queue.get_nowait()
        fetch = get
        while True:
            try:
                line = fetch()
                if line is None:
                    self.process.join(timeout=1)
                    if self.process.is_alive():
                        raise self.AliveAfterEndError("Process is alive after end")
                    return
                if isinstance(line, Exception):
                    raise line
                yield line
            except multiprocessing.queues.Empty:
                if self.process.is_alive():
                    continue
                if fetch is get:
                    # switch to non-blocking mode
                    # to avoid race condition
                    fetch = get_nowait 
                raise self.TerminatedWithoutEndError("Process has ended without end")
    
    def __call__(self):
        import sys
        old_stdout = sys.stdout
        sys.stdout = self
        
        try:
            res = self.fn(*self.args, **self.kwargs)
            self.queue.put(None)
            return res
        except Exception as e:
            self.queue.put(e)
            print(traceback.format_exc(), file=sys.stderr)
            print(str(e), file=sys.stderr)
        finally:
            sys.stdout = old_stdout


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
        ode_data = data['ode']
        solver_data = data['solver']
        job_data = data['job']

        ode_types = odes[ode_name].get_argument_types()
        solver_types = solvers[solver_name].get_argument_types()
        job_types = jobs[job_name].get_argument_types()

        ode_kwargs = {}
        solver_kwargs = {}
        job_kwargs = {}
        for arg, tp in ode_types.items():
            ode_kwargs[arg] = tp(ode_data['args'][arg])
        for arg, tp in solver_types.items():
            solver_kwargs[arg] = tp(solver_data['args'][arg])
        for arg, tp in job_types.items():
            if arg in ['ode', 'solver']:
                continue
            job_kwargs[arg] = tp(job_data['args'][arg])

        ode = odes[ode_name].create(**ode_kwargs)
        solver = solvers[solver_name].create(**solver_kwargs)
        job = jobs[job_name]

        ode.set_t(float(ode_data['variables']['t']))
        for i in range(ode.get_x_size()):
            ode.set_x(i, float(ode_data['variables'][f'x[{i}]']))
        for i in range(ode.get_p_size()):
            ode.set_p(i, float(ode_data['parameters'][f'p[{i}]']))

        job_kwargs['ode'] = ode
        job_kwargs['solver'] = solver
        job.run(**job_kwargs)
        return jsonify({'status': 'success'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def mock_job():
    for i in range(101):
        time.sleep(1)
        print(i)

@app.route('/api/run-job-mock', methods=['POST'])
def run_job_mock():
    try:
        job_id = str(int(time.time() * 1000))
        process = JobProcess(mock_job)
        process.start()
        processes[job_id] = process
        return jsonify({'status': 'started', 'job_id': job_id})
    except Exception as e:
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
            for line in process.get_lines():
                progress = int(line.strip())
                status['progress'] = progress
                status['status'] = 'running' if progress < 100 else 'completed'
                status['message'] = f'Processing...' if progress < 100 else 'Job finished'
                yield f"data: {json.dumps(status)}\n\n"
        except Exception as e:
            status['status'] = 'error'
            status['message'] = f'Error: {str(e)}'
            yield f"data: {json.dumps(status)}\n\n"
        finally:
            process.terminate()
            process.join(timeout=5)
            if process.is_alive():
                process.kill()
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
    scan_components()
    print("Available components:")
    print(f"  ODEs: {list(odes)}")
    print(f"  Solvers: {list(solvers)}")
    print(f"  Jobs: {list(jobs)}")
    print("\nAccess the application at: http://localhost:5001")
    
    app.run(debug=True, host='0.0.0.0', port=5001)