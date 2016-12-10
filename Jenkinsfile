#!groovy

// node {
//   ansiColor("xterm") {
//     checkout scm
//     sh "git clean -fdx"

//     stage("Preflight Checks") {
//       withEnv(["CRYSTAL_CACHE_DIR=${env.WORKSPACE}/.crystal-cache"]) {
//         sh "make std_spec junit_output=.build/reports"
//         junit testResults: ".build/reports/output.xml", healthScaleFactor: 10.0

//         sh "make crystal"
//         sh "bin/crystal tool format --check samples spec src"
//         sh "( find samples -name \"*.cr\" | xargs -L 1 ./bin/crystal build --no-codegen )"
//       }
//     }
//   }
// }

def matrixStep(matrix, architecture, llvmVersion, wrapperCommand = "", linkFlags = "") {
  def crystalFlags = "--target ${architecture} --link-flags=\"${linkFlags}\""

  matrix["Build ${architecture} with LLVM ${llvmVersion}"] = {
    node(architecture) {
      ansiColor("xterm") {
        checkout scm
        sh "git clean -fdx"

        withEnv(["CRYSTAL_CACHE_DIR=${env.WORKSPACE}/.crystal-cache",
                 "LLVM_CONFIG=/usr/bin/llvm-config-${llvmVersion}",
                 "CRYSTAL_FLAGS=${crystalFlags}",
                 "CFLAGS=${linkFlags}",
                 "CXXFLAGS=${linkFlags}",
                 "ARFLAGS=--target ${architecture}"]) {
          sh "${wrapperCommand} make spec junit_output=.build/reports"
          // junit testResults: ".build/reports/output.xml", healthScaleFactor: 10.0
          sh "${wrapperCommand} make crystal"
          sh "${wrapperCommand} make doc"
        }
      }
    }
  }
}

def matrix = [:]
// matrixStep(matrix, "x86_64-linux-gnu", "3.8")
// matrixStep(matrix, "x86_64-linux-gnu", "3.9")
// matrixStep(matrix, "x86_64-linux-gnu", "4.0")
matrixStep(matrix, "i686-linux-gnu", "4.0", "linux32", "-m32")
parallel matrix
