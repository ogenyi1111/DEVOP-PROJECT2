pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Choose deployment environment')
        choice(name: 'VERSION_BUMP', choices: ['none', 'patch', 'minor', 'major'], description: 'Choose version bump type')
    }

    environment {
        DOCKER_IMAGE = 'ikennaogenyi/flask-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
        ANSIBLE_INVENTORY = 'ansible/inventory/hosts'
        ANSIBLE_VAULT_PASSWORD = credentials('ansible-vault-password')
        SLACK_COLOR_SUCCESS = 'good'
        SLACK_COLOR_FAIL = 'danger'
        SLACK_COLOR_DEFAULT = '#FFFF00'
        PATH_SEP = "${isUnix() ? '/' : '\\'}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Version Management') {
            steps {
                script {
                    def currentVersion = readFile('VERSION').trim()
                    echo "Current version: ${currentVersion}"
                    def (major, minor, patch) = currentVersion.tokenize('.').collect { it.toInteger() }

                    switch ("${params.VERSION_BUMP}") {
                        case 'patch':
                            patch++
                            break
                        case 'minor':
                            minor++
                            patch = 0
                            break
                        case 'major':
                            major++
                            minor = 0
                            patch = 0
                            break
                        case 'none':
                            break
                    }

                    def newVersion = "${major}.${minor}.${patch}"
                    writeFile file: 'VERSION', text: newVersion
                    env.DOCKER_TAG = newVersion
                    echo "New version: ${newVersion}"
                    slackSend(color: env.SLACK_COLOR_DEFAULT, message: "🟢 Version bumped to ${newVersion}")
                }
            }
        }

        stage('Load Environment Config') {
            steps {
                script {
                    def config = readYaml file: "config/${params.DEPLOY_ENV}.yml"
                    env.FLASK_ENV = config.flask_env
                    env.FLASK_DEBUG = config.flask_debug
                    slackSend(color: env.SLACK_COLOR_SUCCESS, message: "🌍 Environment config loaded for ${params.DEPLOY_ENV}")
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .'
                    } else {
                        bat 'docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% .'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    if (isUnix()) {
                        sh 'docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} python -m pytest tests/'
                    } else {
                        bat 'docker run --rm %DOCKER_IMAGE%:%DOCKER_TAG% python -m pytest tests/'
                    }
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            echo ${DOCKER_CREDENTIALS_PSW} | docker login -u ${DOCKER_CREDENTIALS_USR} --password-stdin
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                            docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                            docker push ${DOCKER_IMAGE}:latest
                        '''
                    } else {
                        bat '''
                            echo %DOCKER_CREDENTIALS_PSW% | docker login -u %DOCKER_CREDENTIALS_USR% --password-stdin
                            docker push %DOCKER_IMAGE%:%DOCKER_TAG%
                            docker tag %DOCKER_IMAGE%:%DOCKER_TAG% %DOCKER_IMAGE%:latest
                            docker push %DOCKER_IMAGE%:latest
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    if (isUnix()) {
                        sh '''
                            cd ansible
                            ansible-playbook -i ${ANSIBLE_INVENTORY} playbooks/deploy.yml \
                                --vault-password-file <(echo ${ANSIBLE_VAULT_PASSWORD}) \
                                -e "docker_image=${DOCKER_IMAGE}:${DOCKER_TAG}"
                        '''
                    } else {
                        bat '''
                            cd ansible
                            ansible-playbook -i %ANSIBLE_INVENTORY% playbooks/deploy.yml ^
                                --vault-password-file <(echo %ANSIBLE_VAULT_PASSWORD%) ^
                                -e "docker_image=%DOCKER_IMAGE%:%DOCKER_TAG%"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                if (isUnix()) {
                    sh 'docker logout'
                } else {
                    bat 'docker logout'
                }
                cleanWs()
                slackSend(color: '#FFFF00', message: "🟡 Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' finished. Check: ${env.BUILD_URL}")
            }
        }
        success {
            echo 'Pipeline completed successfully!'
            slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' succeeded on *${params.DEPLOY_ENV}*!")
        }
        failure {
            echo 'Pipeline failed!'
            slackSend(color: env.SLACK_COLOR_FAIL, message: "❌ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' failed during *${params.DEPLOY_ENV}* deployment!")
        }
    }
} 