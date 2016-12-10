#!groovy

node {
  ansiColor("xterm") {
    checkout scm
    sh "git clean -fdx"

    stage("Preflight Checks") {
      withEnv(["CRYSTAL_CACHE_DIR=${env.WORKSPACE}/.crystal-cache"]) {
        sh "make std_spec junit_output=.build/reports"
        junit testResults: ".build/reports/output.xml", healthScaleFactor: 10.0

        sh "make crystal"
        sh "bin/crystal tool format --check samples spec src"
        sh "( find samples -name \"*.cr\" | xargs -L 1 ./bin/crystal build --no-codegen )"
      }
    }
  }
}

def matrixStep(matrix, architecture, llvmVersion) {
  matrix["Build ${architecture} with LLVM ${llvmVersion}"] = {
    node(architecture) {
      ansiColor("xterm") {
        checkout scm
        sh "git clean -fdx"

        withEnv(["CRYSTAL_CACHE_DIR=${env.WORKSPACE}/.crystal-cache",
                 "LLVM_CONFIG=/usr/bin/llvm-config-${llvmVersion}",
                 // Fake env var to satisfy withEnv's parser
                 architecture.startsWith("i686-") ? "threads=1" : "fake=true"]) {
          sh "make spec junit_output=.build/reports"
          // junit testResults: ".build/reports/output.xml", healthScaleFactor: 10.0
          sh "make crystal"
          sh "make doc"
        }
      }
    }
  }
}

def matrix = [:]
matrixStep(matrix, "x86_64-linux-gnu", "3.8")
matrixStep(matrix, "x86_64-linux-gnu", "3.9")
matrixStep(matrix, "x86_64-linux-gnu", "4.0")
matrixStep(matrix, "i686-linux-gnu", "3.8")
matrixStep(matrix, "i686-linux-gnu", "3.9")
matrixStep(matrix, "i686-linux-gnu", "4.0")
parallel matrix
