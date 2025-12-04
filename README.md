# SRE Technical Challenge

<https://gist.github.com/parkerd/57c0b11d8683474ac1cd168950211354#sre-technical-challenge>

The chart:

* Deploys the web application using Kubernetes deployment and service
* Runs database migrations via a dedicated batch job
* Ensures migrations complete before the application starts
* Passes environment variables via values.yaml
* Uses standard Helm conventions

## Prerequisites

* Kubernetes cluster (I tested locally with kind and k3s on MacOS)
* Helm 3.x
* kubectl configured for the cluster
* Ability to pull the image: ghcr.io/stordco/sre-technical-challenge
* psql if you want to inspect the database manually

## Structure

```bash
.
├── Chart.yaml
├── README.md
├── templates
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── migrate-job.yaml
│   └── service.yaml
└── values.yaml
```

## Create namespace (Optional)

This step is optional because we pass `--create-namespace` in the install command but if you don't want to do it that way, you can create the namespace manually.

```bash
kubectl create namespace stord
```

## Step 1: Install PostgreSQL

The application expects PostgreSQL to exist prior to deployment.

```bash
NAMESPACE=stord

helm install sre-db oci://registry-1.docker.io/bitnamicharts/postgresql \
  --create-namespace \
  --namespace $NAMESPACE \
  --set auth.database=sre-technical-challenge \
  --set auth.postgresPassword=password
```

### Wait until PostgreSQL is ready

```bash
kubectl get pods -n stord
```

You should see the psql pod running

```bash
NAME                  READY   STATUS    RESTARTS   AGE
sre-db-postgresql-0   1/1     Running   0          33s
```

## Step 2: Install the application

From the chart root directory

```bash
helm install sre-app . \
  --debug \
  --namespace $NAMESPACE \
  --values values.yaml
```

### Verify resources

```bash
kubectl get all -n stord
```

```bash
NAME                                           READY   STATUS    RESTARTS   AGE
pod/sre-db-postgresql-0                        1/1     Running   0          69s
pod/sre-technical-challenge-7548dddb7b-26vf2   1/1     Running   0          14s

NAME                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/sre-app-sre-technical-challenge   ClusterIP   10.96.8.167     <none>        80/TCP     14s
service/sre-db-postgresql                 ClusterIP   10.96.215.145   <none>        5432/TCP   69s
service/sre-db-postgresql-hl              ClusterIP   None            <none>        5432/TCP   69s

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/sre-technical-challenge   1/1     1            1           14s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/sre-technical-challenge-7548dddb7b   1         1         1       14s

NAME                                 READY   AGE
statefulset.apps/sre-db-postgresql   1/1     69s
```

You should see the required psql pod, services, and statefulset as well as the application pod, service, and replicaset.

## Step 3: Validate application

### Health endpoint

Forward local port to the service

```bash
kubectl port-forward -n stord svc/sre-app-sre-technical-challenge 8080:80
```

From another terminal

```bash
curl -i http://localhost:8080/_health
```

You should receive HTTP 200.

### Application endpoint

```bash
curl -i http://localhost:8080/todos
```

A successful response shows

* The application is running
* The database connection works
* Migrations have completed successfully

## Database verification

```bash
kubectl port-forward -n stord svc/sre-db-postgresql 55432:5432

psql postgresql://postgres:password@127.0.0.1:55432/sre-technical-challenge

\dt
```

## Notes

### How migration works

Database migrations are run using a dedicated k8s job rather than as part of the Deployment.

#### How it’s implemented

* The Job runs the same image as the app
* It uses args: ["migrate"] to switch the container into migration mode
* It receives the same environment variables as the application
* It is installed as a Helm pre-install and pre-upgrade hook

#### Behavior

* On install, migrations run before the deployment is created
* On upgrade, migrations run before the deployment is updated
* If migration fails, Helm fails the release
* The application does not start unless migrations succeed
* Migration does not run on pod restarts or scaling events

This guarantees that schema changes are applied once per release and not tied to pod lifecycle.

### Environment variables

The chart expects configuration via values.yaml under the env key.

All entries in this map are passed through to the container with no template changes required

Example

```yaml
env:
  DATABASE_URL: postgresql://...
  POOL_SIZE: 10
  SECRET_KEY_BASE: ...
  PHX_HOST: localhost
```

Adding or removing variables does not require chart modification.

## Cleanup

To remove the application

```bash
helm uninstall sre-app -n stord
```

To remove the DB

```bash
helm uninstall sre-db -n stord
```
