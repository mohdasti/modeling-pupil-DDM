# Contributing to Modeling Pupil-DDM

Thank you for your interest in contributing to the Modeling Pupil-DDM project! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- **R** (≥ 4.0.0) with required packages
- **Python** (≥ 3.8) with scientific computing libraries
- **MATLAB** (≥ R2020a) for preprocessing
- **Git** for version control

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/modeling-pupil-DDM.git
   cd modeling-pupil-DDM
   ```

3. **Set up the development environment**:
   ```bash
   # Using conda (recommended)
   conda env create -f environment.yml
   conda activate modeling-pupil-ddm

   # Or using pip
   pip install -r requirements.txt
   ```

4. **Install R packages**:
   ```r
   Rscript scripts/setup/install_r_packages.R
   ```

5. **Create a development branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📝 Contribution Guidelines

### Code Style

#### R Code
- Follow the [tidyverse style guide](https://style.tidyverse.org/)
- Use meaningful variable and function names
- Add comments for complex logic
- Use `here::here()` for file paths
- Prefer `%>%` for data manipulation

#### Python Code
- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
- Use meaningful variable and function names
- Add docstrings for functions and classes
- Use type hints where appropriate

#### MATLAB Code
- Use camelCase for variable names
- Add comments for complex sections
- Use consistent indentation (4 spaces)

### Documentation

- Update README.md if adding new features
- Add docstrings to new functions
- Update configuration files if needed
- Include examples in documentation

### Testing

- Write tests for new functionality
- Ensure existing tests still pass
- Test on different operating systems if possible

## 🔄 Workflow

### 1. Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write code following the style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   # Python tests
   python -m pytest tests/test_data_processing.py -v

   # R tests
   Rscript tests/test_models.R
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add feature: brief description of changes"
   ```

### 2. Submitting Changes

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request**:
   - Go to the GitHub repository
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR template
   - Submit the PR

### 3. Review Process

- Maintainers will review your PR
- Address any feedback or requested changes
- Once approved, your PR will be merged

## 📋 Pull Request Template

When creating a pull request, please include:

### Description
- Brief description of changes
- Motivation for the changes
- Any breaking changes

### Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

### Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Documentation updated

### Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)

## 🐛 Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Description**: Clear description of the bug
2. **Steps to Reproduce**: Detailed steps to reproduce the issue
3. **Expected Behavior**: What you expected to happen
4. **Actual Behavior**: What actually happened
5. **Environment**: OS, R version, Python version, etc.
6. **Screenshots**: If applicable, include screenshots

### Feature Requests

When requesting features, please include:

1. **Description**: Clear description of the feature
2. **Motivation**: Why this feature would be useful
3. **Use Cases**: Specific examples of how it would be used
4. **Alternatives**: Any alternative solutions considered

## 🧪 Testing Guidelines

### Running Tests

```bash
# Python tests
python -m pytest tests/ -v

# R tests
Rscript tests/test_models.R

# Integration tests
bash scripts/utilities/run_integration_tests.sh
```

### Writing Tests

#### Python Tests
- Use pytest for testing
- Test both success and failure cases
- Use fixtures for common test data
- Mock external dependencies

#### R Tests
- Use testthat for testing
- Test both success and failure cases
- Use helper functions for common operations
- Test edge cases

## 📚 Documentation Guidelines

### Code Documentation

#### R Functions
```r
#' Brief description of function
#'
#' Longer description if needed
#'
#' @param param1 Description of parameter 1
#' @param param2 Description of parameter 2
#' @return Description of return value
#' @examples
#' # Example usage
#' function_name(param1, param2)
function_name <- function(param1, param2) {
  # Function implementation
}
```

#### Python Functions
```python
def function_name(param1, param2):
    """
    Brief description of function
    
    Longer description if needed
    
    Parameters
    ----------
    param1 : type
        Description of parameter 1
    param2 : type
        Description of parameter 2
        
    Returns
    -------
    return_type
        Description of return value
        
    Examples
    --------
    >>> function_name(param1, param2)
    expected_output
    """
    # Function implementation
```

### README Updates

When adding new features:
- Update the feature list
- Add usage examples
- Update installation instructions if needed
- Update the quick start guide

## 🔧 Development Tools

### Recommended Tools

- **RStudio** for R development
- **VS Code** or **PyCharm** for Python development
- **MATLAB** for MATLAB development
- **Git** for version control

### Useful Extensions

- **R**: lintr, styler, devtools
- **Python**: black, flake8, pytest
- **Git**: GitLens, Git Graph

## 📞 Getting Help

### Communication Channels

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For general questions and discussions
- **Email**: For private or sensitive matters

### Code of Conduct

Please note that this project follows a code of conduct. By participating, you agree to uphold this code.

## 🎯 Areas for Contribution

### High Priority

- **Bug fixes**: Fixing existing issues
- **Documentation**: Improving documentation
- **Tests**: Adding test coverage
- **Performance**: Optimizing code performance

### Medium Priority

- **New features**: Adding new analysis methods
- **Visualization**: Improving plots and figures
- **Integration**: Better integration between languages
- **Cloud deployment**: Improving cloud deployment

### Low Priority

- **Refactoring**: Code organization improvements
- **Style**: Code style improvements
- **Examples**: Adding more examples
- **Tutorials**: Creating tutorials

## 🏆 Recognition

Contributors will be recognized in:
- **README.md**: Listed as contributors
- **Release notes**: Mentioned in release notes
- **Documentation**: Credited in relevant sections

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## 🙏 Thank You

Thank you for contributing to the Modeling Pupil-DDM project! Your contributions help make this project better for everyone.

---

**Note**: This contributing guide is a living document. Please suggest improvements or clarifications through issues or pull requests.
