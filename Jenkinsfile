pipeline {
    agent any 

    environment {
        DOCKER_IMAGE_BASE = "wiemkbaier/clinic_app"
        IMAGE_TAG = "${env.TAG_NAME ?: env.BUILD_NUMBER}"
        DOCKER_IMAGE_FULL = "${DOCKER_IMAGE_BASE}:${IMAGE_TAG}"
        DOCKER_CREDENTIALS_ID = "dockerhub-cred"
        SMOKE_CONTAINER_NAME = "clinic_app_smoke_test"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Checkout du code source sur : ${env.BRANCH_NAME ?: env.TAG_NAME}"
            }
        }

        stage('Setup') {
            steps {
                bat 'npm install -g pnpm'
                bat 'pnpm install --no-frozen-lockfile'
            }
        }

        stage('Build') {
            steps {
                bat 'pnpm run build'
            }
        }

        stage('Docker Build') {
            when {
                expression { 
                    // Construire si master, tag ou PR
                    return (env.BRANCH_NAME?.trim() == 'master') || (env.TAG_NAME?.trim()) || (env.CHANGE_ID?.trim())
                }
            }
            steps {
                echo "Construction de l'image Docker : ${DOCKER_IMAGE_FULL}"
                bat "docker build -t ${DOCKER_IMAGE_FULL} -f Dockerfile ."
            }
        }

        stage('Docker Push') {
            when {
                expression { 
                    // Pousser seulement si master ou tag (pas PR)
                    return (env.BRANCH_NAME?.trim() == 'master') || (env.TAG_NAME?.trim())
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    passwordVariable: 'DOCKER_PASSWORD',
                    usernameVariable: 'DOCKER_USERNAME'
                )]) {
                    echo "Connexion à Docker Hub"
                    bat "docker login -u %DOCKER_USERNAME% -p %DOCKER_PASSWORD%"

                    echo "Push de l'image Docker : ${DOCKER_IMAGE_FULL}"
                    bat "docker push ${DOCKER_IMAGE_FULL}"

                    // Toujours taguer et pousser latest sur master ou tag
                    bat "docker tag ${DOCKER_IMAGE_FULL} ${DOCKER_IMAGE_BASE}:latest"
                    bat "docker push ${DOCKER_IMAGE_BASE}:latest"
                }
            }
        }

        stage('Smoke Test') {
            when {
                expression { 
                    // Test sur master, tag ou PR
                    return (env.BRANCH_NAME?.trim() == 'master') || (env.TAG_NAME?.trim()) || (env.CHANGE_ID?.trim())
                }
            }
            steps {
                script {
                    echo "Lancement du container pour Smoke Test"
                    bat "docker run -d --rm --name ${SMOKE_CONTAINER_NAME} -p 3000:3000 ${DOCKER_IMAGE_FULL}"

                    powershell """
                        \$SMOKE_REPORT = "smoke_test_report.txt"
                        \$PORT = 3000
                        "--- Début du Smoke Test ---" | Out-File \$SMOKE_REPORT
                        Start-Sleep -Seconds 10
                        try {
                            \$response = Invoke-WebRequest -Uri http://localhost:\$PORT -UseBasicParsing
                            \$HTTP_STATUS = \$response.StatusCode
                        } catch {
                            \$HTTP_STATUS = 500
                        }
                        if (\$HTTP_STATUS -eq 200) {
                            "[PASSED] HTTP 200 OK" | Out-File \$SMOKE_REPORT -Append
                            exit 0
                        } else {
                            "[FAILED] HTTP \$HTTP_STATUS reçu" | Out-File \$SMOKE_REPORT -Append
                            exit 1
                        }
                    """

                    bat "docker stop ${SMOKE_CONTAINER_NAME}"
                }
            }
        }

        stage('Archive Artifacts') {
            when {
                expression { return (env.BRANCH_NAME?.trim() == 'master') || (env.TAG_NAME?.trim()) }
            }
            steps {
                archiveArtifacts artifacts: 'smoke_test_report.txt, target/logs/*.log', fingerprint: true
                echo "Artifacts archivés."
            }
        }

        stage('Cleanup') {
            steps {
                echo "Nettoyage des ressources Docker"
                bat 'docker system prune -f'
            }
        }
    }
}
