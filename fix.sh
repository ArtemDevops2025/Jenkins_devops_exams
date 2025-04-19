# 1. Clean up old broken pods
for ns in dev qa; do
  kubectl delete pods -n $ns -l app=cast-service --force --grace-period=0
done

# 2. Ensure correct image is built and pushed
cd cast-service
docker build -t art2025/jenkins-exam:cast .
docker push art2025/jenkins-exam:cast

# 3. Update deployments in all non-prod namespaces
for ns in dev qa; do
  kubectl set image deployment/cast-deployment \
    cast-service=art2025/jenkins-exam:cast -n $ns
done

# 4. Verify
watch 'kubectl get pods -n dev -o wide && kubectl get pods -n qa -o wide'