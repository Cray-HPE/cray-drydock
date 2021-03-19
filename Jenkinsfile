@Library('dst-shared@master') _

dockerBuildPipeline {
 app = "sonar"
 name = "cms-sonar"
 description = "Cray management system sonar utility"
 repository = "cray"
 imagePrefix = "cray"
 product = "csm"
 githubPushRepo = "Cray-HPE/cray-drydock"
 githubPushBranches = /(release\/.*|master)/
}
