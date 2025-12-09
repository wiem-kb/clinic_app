// Pipeline Jenkins déclarative pour l'application Next.js (clinic_app)
// Implémente les 3 flux requis : PR, Push sur dev, Tag vX.Y.Z
// Adapté pour un agent d'exécution Windows (utilisation de 'bat' et 'powershell')

pipeline {
    // Utiliser un agent Docker pour l'exécution de la pipeline
    agent {
        docker {
            image 'node:20-alpine'
            args '-u root'
        }
    }

    // Variables d'environnement
    environment {
        // Nom de l'image Docker. Remplacez 'votre_registry' par votre registre
        DOCKER_IMAGE_BASE = "votre_registry/clinic_app"
        // Tag de l'image basé sur le numéro de build de Jenkins ou le tag Git
        IMAGE_TAG = "${env.TAG_NAME ?: env.BUILD_NUMBER}"
        // Nom complet de l'image avec tag
        DOCKER_IMAGE_FULL = "${DOCKER_IMAGE_BASE}:${IMAGE_TAG}"
        // ID des credentials Docker configurés dans Jenkins
        DOCKER_CREDENTIALS_ID = "docker-registry-credentials"
        // Nom du conteneur temporaire pour le smoke test
        SMOKE_CONTAINER_NAME = "clinic_app_smoke_test"
    }

    stages {
        stage('Checkout') {
            steps {
                // Le SCM est géré automatiquement par la Multibranch Pipeline
                echo "Checkout du code source sur la branche/tag ${env.BRANCH_NAME ?: env.TAG_NAME}"
            }
        }

        stage('Setup') {
            steps {
                // S'assurer que pnpm est installé et installer les dépendances
                bat 'npm install -g pnpm'
                bat 'pnpm install --frozen-lockfile'
            }
        }

        stage('Build') {
            steps {
                // Construction de l'application Next.js
                bat 'pnpm run build'
            }
        }

        stage('Docker Build') {
            when {
                // Exécuter pour les push sur 'dev' et les tags, mais pas pour les PR
                expression { return env.BRANCH_NAME == 'dev' || env.TAG_NAME != null || env.CHANGE_ID != null }
            }
            steps {
                // Utilisation de bat pour le docker build
                bat "docker build -t ${DOCKER_IMAGE_FULL} -f Dockerfile ."
            }
        }

        stage('Docker Push') {
            when {
                // Exécuter pour les push sur 'dev' et les tags
                expression { return env.BRANCH_NAME == 'dev' || env.TAG_NAME != null }
            }
            steps {
                // Pousser l'image vers le registre Docker (uniquement pour les tags et dev)
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    // Utilisation de bat pour les commandes docker
                    bat "docker login -u %DOCKER_USERNAME% -p %DOCKER_PASSWORD% ${DOCKER_IMAGE_BASE.split('/')[0]}"
                    bat "docker push ${DOCKER_IMAGE_FULL}"
                    // Pousser le tag 'latest' uniquement pour la branche 'dev' ou le tag
                    if (env.BRANCH_NAME == 'dev' || env.TAG_NAME != null) {
                        bat "docker tag ${DOCKER_IMAGE_FULL} ${DOCKER_IMAGE_BASE}:latest"
                        bat "docker push ${DOCKER_IMAGE_BASE}:latest"
                    }
                }
            }
        }

        stage('Smoke Test') {
            when {
                // Exécuter pour tous les flux (PR, dev, tag)
                expression { return env.BRANCH_NAME == 'dev' || env.TAG_NAME != null || env.CHANGE_ID != null }
            }
            steps {
                script {
                    // Démarrer le conteneur pour le smoke test
                    bat "docker run -d --rm --name ${SMOKE_CONTAINER_NAME} -p 3000:3000 ${DOCKER_IMAGE_FULL}"
                    
                    // Logique du Smoke Test intégrée en PowerShell
                    powershell """
                        \$SMOKE_REPORT = "smoke_test_report.txt"
                        \$PORT = 3000
                        
                        "--- Début du Smoke Test (intégré) ---" | Out-File \$SMOKE_REPORT
                        
                        # Attendre que le service démarre
                        Start-Sleep -Seconds 10
                        
                        try {
                            \$response = Invoke-WebRequest -Uri http://localhost:\$PORT -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
                            \$HTTP_STATUS = \$response.StatusCode
                        } catch {
                            \$HTTP_STATUS = \$_.Exception.Response.StatusCode
                        }
                        
                        if (\$HTTP_STATUS -eq 200) {
                            "[PASSED] Réponse HTTP 200 reçue sur le port \$PORT." | Out-File \$SMOKE_REPORT -Append
                            \$FINAL_STATUS = "PASSED"
                            \$EXIT_CODE = 0
                        } else {
                            "[FAILED] Réponse HTTP \$HTTP_STATUS reçue (attendu 200)." | Out-File \$SMOKE_REPORT -Append
                            \$FINAL_STATUS = "FAILED"
                            \$EXIT_CODE = 1
                        }
                        
                        "--- Fin du Smoke Test ---" | Out-File \$SMOKE_REPORT -Append
                        "Statut final: \$FINAL_STATUS" | Out-File \$SMOKE_REPORT -Append
                        
                        Get-Content \$SMOKE_REPORT
                        
                        # Le script PowerShell doit échouer si le test échoue
                        exit \$EXIT_CODE
                    """
                    
                    // Arrêter le conteneur
                    bat "docker stop ${SMOKE_CONTAINER_NAME}"
                }
            }
        }

        stage('Archive Artifacts') {
            when {
                // Exécuter pour les push sur 'dev' et les tags
                expression { return env.BRANCH_NAME == 'dev' || env.TAG_NAME != null }
            }
            steps {
                // Archiver les logs de build, le rapport de smoke test et le rapport de pipeline
                archiveArtifacts artifacts: 'smoke_test_report.txt, target/logs/*.log', fingerprint: true
                // Note: L'archivage du rapport de pipeline dépend d'un plugin Jenkins (ex: build-flow-plugin)
                echo "Artefacts archivés: smoke_test_report.txt et logs de build (si existants)."
            }
        }

        stage('Cleanup (Recommandé)') {
            steps {
                // Supprimer les images Docker locales non utilisées pour libérer de l'espace
                bat 'docker system prune -f'
            }
        }
    }
}
