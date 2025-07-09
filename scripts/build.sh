#!/usr/bin/env bash

# Use environment variables from Makefile (no defaults needed)
CWD=$(pwd)
echo "Working in directory: $CWD"

# Validate required environment variables
if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_VERSION" ] || [ -z "$AUTHOR_NAME" ] || [ -z "$AUTHOR_EMAIL" ]; then
    echo "Error: Missing required environment variables from Makefile"
    echo "Required: PROJECT_NAME, PROJECT_VERSION, PROJECT_DESCRIPTION, AUTHOR_NAME, AUTHOR_EMAIL"
    exit 1
fi

# Display configuration from Makefile
echo "Project Configuration:"
echo "  Name: ${PROJECT_NAME}"
echo "  Version: ${PROJECT_VERSION}"
echo "  Description: ${PROJECT_DESCRIPTION}"
echo "  Author: ${AUTHOR_NAME} <${AUTHOR_EMAIL}>"
echo

# Initialize project - handle both template and direct modification scenarios
if [ -f "pyproject.template.toml" ]; then
    echo "Generating pyproject.toml from template..."
    
    # Use envsubst for cleaner variable substitution
    if command -v envsubst >/dev/null 2>&1; then
        # Export variables for envsubst
        export PROJECT_NAME PROJECT_VERSION PROJECT_DESCRIPTION AUTHOR_NAME AUTHOR_EMAIL
        envsubst < pyproject.template.toml > pyproject.toml
    else
        # Fallback to sed if envsubst is not available
        sed -e "s/\${PROJECT_NAME}/${PROJECT_NAME}/g" \
            -e "s/\${PROJECT_VERSION}/${PROJECT_VERSION}/g" \
            -e "s/\${PROJECT_DESCRIPTION}/${PROJECT_DESCRIPTION}/g" \
            -e "s/\${AUTHOR_NAME}/${AUTHOR_NAME}/g" \
            -e "s/\${AUTHOR_EMAIL}/${AUTHOR_EMAIL}/g" \
            pyproject.template.toml > pyproject.toml
    fi
    
    echo "✓ pyproject.toml generated from template"
    
else
    echo "Error: Neither pyproject.template.toml nor pyproject.toml found"
    exit 1
fi

# Create and activate virtual environment
if [ ! -d .venv ]; then
    python3 -m venv .venv
    echo ".venv created"
fi

source .venv/bin/activate
pip install --upgrade pip

# Priority order: pyproject.toml > requirements.txt > setup.py
if [ -f "pyproject.toml" ]; then
    echo "Installing from pyproject.toml..."
    if grep -q "optional-dependencies" pyproject.toml; then
        pip install -e .[dev]
    else
        pip install -e .
    fi
elif [ -f "requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    pip install -r requirements.txt
elif [ -f "setup.py" ]; then
    echo "Installing from setup.py..."
    pip install -e .
else
    echo "No dependency configuration found in $CWD"
    exit 1
fi

pip list
