Trivy scan results – Docker image v4

Image: cloudrun-platform-assessment:v4
Scanner: Trivy v0.76.2
Base image: Python 3.12 slim (Debian 13.7)

Command:

trivy image --severity HIGH,CRITICAL --ignore-unfixed cloudrun-platform-assessment:v4

Results:

Debian OS packages: 0 HIGH and 0 CRITICAL vulnerabilities.

FastAPI 0.162.2: no findings.

Starlette 1.10.0: no findings.

pip 26.3: no findings.

One remaining HIGH finding: CVE-2025-47273, attributed by Trivy to setuptools 70.3.0 (fixed in 78.1.1).

Investigation of the setuptools finding

The reported package could not be verified in the image:

pip show setuptools returned package not found in both the virtual environment and system Python.

Filesystem searches under /usr and /opt found no setuptools files.

The Debian package database contained no setuptools package.

Trivy reported the finding without a package path (PkgPath: null).

Trivy warned that third-party SBOM data may lead to inaccurate vulnerability detection.