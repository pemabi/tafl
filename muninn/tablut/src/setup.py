from setuptools import setup, Extension
from Cython.Build import cythonize
import numpy

ext_modules = [
    Extension(
        "tablut",
        ["tablut.pyx"],
        extra_compile_args=['-Wno-unreachable-code', '-Wno-unreachable-code-fallthrough'],
        include_dirs=[numpy.get_include()]
    )
]

setup(
    ext_modules=cythonize(ext_modules)
)
