#!/usr/bin/env python3
"""
Web-based UI for Dynamical Systems
A Flask web application for running dynamical systems simulations.
"""

from flask import (
    Flask,
    render_template,
    request,
    jsonify,
    Response,
)
from flask_cors import CORS
import json
import datetime
import sys
import traceback
import subprocess
import uuid
import webbrowser
import threading
import time

from dynamical_systems import components, generate_cmd

app = Flask(__name__)
CORS(app)
app.secret_key = "dynamical-systems-ui-key"

processes = {}


@app.route("/")
def index():
    """Main page."""
    return render_template("index.html")


@app.route("/api/get-odes", methods=["GET"])
def get_odes():
    return jsonify(list(components["ode"]))


@app.route("/api/get-solvers", methods=["GET"])
def get_solvers():
    return jsonify(list(components["solver"]))


@app.route("/api/get-jobs", methods=["GET"])
def get_jobs():
    return jsonify(list(components["job"]))


@app.route("/api/get-ode-arguments/<name>", methods=["GET"])
def get_ode_arguments(name):
    try:
        return jsonify(
            [
                {"name": arg["name"], "type": arg["type"].__name__}
                for arg in components["ode"][name].get_argument_types()
            ]
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/get-solver-arguments/<name>", methods=["GET"])
def get_solver_arguments(name):
    try:
        return jsonify(
            [
                {"name": arg["name"], "type": arg["type"].__name__}
                for arg in components["solver"][name].get_argument_types()
            ]
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/get-job-arguments/<name>", methods=["GET"])
def get_job_arguments(name):
    try:
        return jsonify(
            [
                {"name": arg["name"], "type": arg["type"].__name__}
                for arg in components["job"][name].get_argument_types()
            ]
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/get-ode-state/<ode_name>", methods=["POST"])
def get_ode_state(ode_name):
    try:
        data = request.get_json()
        kwargs = {}
        for arg in components["ode"][ode_name].get_argument_types():
            name = arg["name"]
            tp = arg["type"]
            value = data[name]
            kwargs[name] = tp(value)
        ode = components["ode"][ode_name].create(**kwargs)
        res = {
            "variables": [
                {"name": "t"},
                *[{"name": f"x[{i}]"} for i in range(ode.get_x_size())],
            ],
            "parameters": [{"name": f"p[{i}]"} for i in range(ode.get_p_size())],
        }
        return jsonify(res)
    except Exception as e:
        print(e, file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        return jsonify({"error": str(e)}), 500


@app.route("/api/run-job/<ode_name>/<solver_name>/<job_name>", methods=["POST"])
def run_job(ode_name, solver_name, job_name):
    try:
        job_id = str(uuid.uuid4())
        data = request.get_json()
        ode_data = data["ode"]
        solver_data = data["solver"]
        job_data = data["job"]

        ode_types = components["ode"][ode_name].get_argument_types()
        solver_types = components["solver"][solver_name].get_argument_types()
        job_types = components["job"][job_name].get_argument_types()

        ode_kwargs = {}
        solver_kwargs = {}
        job_kwargs = {}
        for arg in ode_types:
            name = arg["name"]
            tp = arg["type"]
            value = ode_data["args"][name]
            ode_kwargs[name] = tp(value)
        for arg in solver_types:
            name = arg["name"]
            tp = arg["type"]
            value = solver_data["args"][name]
            solver_kwargs[name] = tp(value)
        for arg in job_types:
            name = arg["name"]
            tp = arg["type"]
            value = job_data["args"][name]
            job_kwargs[name] = tp(value)

        try:
            ode = components["ode"][ode_name].create(**ode_kwargs)
            ode.set_t(float(ode_data["variables"]["t"]))
            ode.set_x(
                [
                    float(ode_data["variables"][f"x[{i}]"])
                    for i in range(ode.get_x_size())
                ]
            )
            ode.set_p(
                [
                    float(ode_data["parameters"][f"p[{i}]"])
                    for i in range(ode.get_p_size())
                ]
            )
        except Exception as e:
            raise type(e)(f"ODE Error: {e}") from e
        try:
            solver = components["solver"][solver_name].create(**solver_kwargs)
        except Exception as e:
            raise type(e)(f"Solver Error: {e}") from e
        try:
            job = components["job"][job_name].create(**job_kwargs)
        except Exception as e:
            raise type(e)(f"Job Error: {e}") from e

        cmd = generate_cmd(ode, solver, job)
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0,  # Unbuffered
            universal_newlines=True,
        )
        processes[job_id] = process
        return jsonify({"status": "started", "job_id": job_id})
    except Exception as e:
        print(e, file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        return jsonify({"error": str(e)}), 500


@app.route("/api/cancel-job/<job_id>", methods=["POST"])
def cancel_job(job_id):
    if job_id not in processes:
        return jsonify({"error": "Job not found"}), 404
    process = processes[job_id]
    process.terminate()
    if process.poll() is None:
        process.kill()
        process.wait()
    del processes[job_id]
    return jsonify({"status": "cancelled"})


@app.route("/api/job-event-stream/<job_id>")
def job_event_stream(job_id):
    def generate():
        status = {"progress": 0, "status": "error", "message": ""}
        if job_id not in processes:
            status["status"] = "error"
            status["message"] = "Job not found"
            yield f"data: {json.dumps(status)}\n\n"
            return

        process = processes[job_id]
        progress = None

        if not process:
            status["status"] = "error"
            status["message"] = "Failed to start process"
            yield f"data: {json.dumps(status)}\n\n"
            return
        try:
            timestamps = []
            for line in process.stdout:
                progress = int(line.strip())
                timestamps.append(datetime.datetime.now())
                message = None
                if progress == 0:
                    message = "Job started"
                elif progress == 100:
                    message = "Job finished"
                else:
                    diffs = [
                        timestamps[i + 1] - timestamps[i]
                        for i in range(len(timestamps) - 1)
                    ]
                    avg_diff = sum(diffs, datetime.timedelta()) / len(diffs)
                    time_remaining = (100 - progress) * avg_diff

                    # Extract time components
                    total_seconds = int(time_remaining.total_seconds())
                    days = total_seconds // 86400
                    hours = (total_seconds % 86400) // 3600
                    minutes = (total_seconds % 3600) // 60
                    seconds = total_seconds % 60

                    # Create list of non-zero components
                    components = []
                    if days > 0:
                        components.append((days, "day" if days == 1 else "days"))
                    if hours > 0:
                        components.append((hours, "hour" if hours == 1 else "hours"))
                    if minutes > 0:
                        components.append(
                            (minutes, "minute" if minutes == 1 else "minutes")
                        )
                    if seconds > 0:
                        components.append(
                            (seconds, "second" if seconds == 1 else "seconds")
                        )

                    # Get the biggest and second biggest components
                    if len(components) >= 2:
                        biggest = components[0]
                        second_biggest = components[1]
                        time_str = f"{biggest[0]} {biggest[1]}, {second_biggest[0]} {second_biggest[1]}"
                    elif len(components) == 1:
                        biggest = components[0]
                        time_str = f"{biggest[0]} {biggest[1]}"
                    else:
                        time_str = "less than a second"

                    message = f"Calculating... {time_str} remaining"
                if progress > 100:
                    raise ValueError(f"Progress is greater than 100: {progress}")
                status["progress"] = progress
                status["status"] = "running" if progress < 100 else "completed"
                status["message"] = message
                yield f"data: {json.dumps(status)}\n\n"
            if progress is None or progress < 100:
                raise RuntimeError(process.stderr.read())
        except Exception as e:
            status["status"] = "error"
            status["message"] = f"Error: {str(e)}"
            yield f"data: {json.dumps(status)}\n\n"
            print(e, file=sys.stderr)
            print(traceback.format_exc(), file=sys.stderr)
        finally:
            process.terminate()
            if process.poll() is None:
                process.kill()
                process.wait()
        if job_id in processes:
            del processes[job_id]

    return Response(
        generate(),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
        },
    )


def main(port=5001, debug=False):
    print("Starting Dynamical Systems Web UI...")
    print("Scanning for components...")
    print("Available components:")
    print(f"  ODEs: {list(components['ode'])}")
    print(f"  Solvers: {list(components['solver'])}")
    print(f"  Jobs: {list(components['job'])}")
    print("\nServer starting... Opening browser automatically!")
    print(f"Access the application at: http://localhost:{port}")

    # Function to open browser after a short delay
    def open_browser():
        time.sleep(1.5)  # Wait for server to start
        webbrowser.open(f"http://localhost:{port}")

    # Start browser opening in a separate thread
    browser_thread = threading.Thread(target=open_browser)
    browser_thread.daemon = True
    browser_thread.start()

    app.run(debug=debug, host="0.0.0.0", port=port)
