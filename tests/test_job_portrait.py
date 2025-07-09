import pytest
import os
import subprocess
import time
from dynamical_systems import Job, generate_module_cmd


def test_job(job_factory, ode, solver):
    file = "portrait.txt"
    job = job_factory.create(t_step=0.5, t_end=1.0, file=file)
    assert job_factory.get_argument_types() == [
        {"name": "t_step", "type": float},
        {"name": "t_end", "type": float},
        {"name": "file", "type": str},
    ]
    assert job_factory.get_name() == "portrait"
    assert isinstance(job, Job)
    assert job.get_arguments() == [
        {"name": "t_step", "value": 0.5},
        {"name": "t_end", "value": 1.0},
        {"name": "file", "value": file},
    ]
    job.run(ode, solver)
    assert os.path.exists(file)
    os.remove(file)


def test_errors(job_factory):
    with pytest.raises(Exception):
        job_factory.create(t_step="0.5", t_end=1.0, file="test_errors.txt")
    with pytest.raises(Exception):
        job_factory.create(t_step=0.5, t_end="1.0", file="test_errors.txt")
    with pytest.raises(Exception):
        job_factory.create(t_step=0.5, t_end=1.0, file=123)


def test_module_cmd(job_factory, ode, solver):
    file = "test_progress.txt"
    job = job_factory.create(t_step=0.5, t_end=1.0, file=file)
    process = subprocess.run(
        generate_module_cmd(ode, solver, job), text=True, capture_output=True
    )

    # Better error reporting
    if process.returncode != 0:
        print(f"Return code: {process.returncode}")
        print(f"stdout: {process.stdout}")
        print(f"stderr: {process.stderr}")

    assert process.returncode == 0
    assert os.path.exists(file)
    os.remove(file)
    lines = [int(line.strip()) for line in process.stdout.split("\n") if line.strip()]
    assert lines == list(range(101))
