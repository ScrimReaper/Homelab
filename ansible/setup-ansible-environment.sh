#!/bin/bash

VENV_DIR=venv

if ! type python &>/dev/null; then
  echo "Python is not installed"
  exit 1
fi

# remove existing venv
if [[ -d $VENV_DIR ]]; then
  rm -rf "$VENV_DIR"
fi

echo "Creating Virtual Environment"

python -m venv "$VENV_DIR"

echo "Entering Virtual Environment"

source venv/bin/activate

PYTHON_REQUIREMENTS_FILE=requirements.txt

ANSIBLE_REQUIREMENTS_FILE=requirements.yml

if [[ -f $PYTHON_REQUIREMENTS_FILE ]]; then

  echo "Installing Python dependencies"
  pip install -r "$PYTHON_REQUIREMENTS_FILE"
fi

if [[ -f $ANSIBLE_REQUIREMENTS_FILE ]]; then

  echo "Installing Ansible dependencies"
  ansible-galaxy collection install -r "$ANSIBLE_REQUIREMENTS_FILE"

fi

echo "All finished, now simply source venv/bin/activate"



