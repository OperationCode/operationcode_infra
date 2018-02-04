# Operation Code's Kubernetes Cluster.

Greetings! Much of Operation Code's web site runs in a [Kubernetes](https://kubernetes.io/) cluster.  These instructions will guide you through setting up access to our cluster so you can run rails console, tail logs, and more!

## What you need
* An Operation Code Google account in the form of walt@operationcode.org
* Access to 1Password to get the Google Application Client Secret and the Kubernetes cluster Certificate Authority data

# From Linux (Ubuntu)

## Installing the Kubernetes Command Line

This is what you will use to interact with our Kubernetes cluster - where both the front end and back end of the site runs.

* Install the Kubernetes command line
```bash
$ sudo snap install kubectl --classic
```

## Authenticating to the Operation Code Kubernetes Cluster

You will use your email@operationcode.org gmail account to authenticate to our cluster. We use a helper to do this - the k8s-oidc-helper.  This helper is written in go - and to use it, we'll need to install the go language and create some configuration.

### Installing Go

First, install the go language on your workstation with these commands (you will want to do it this way, as the one in the ubuntu package manager is quite out of date)

```bash
$ sudo curl -O https://storage.googleapis.com/golang/go1.9.3.linux-amd64.tar.gz
$ sudo tar -xvf go1.9.3.linux-amd64.tar.gz
$ sudo mv go /usr/local
```

Now, let's add in some configuration for go. Open up your profile file

```bash
$ vim ~/.profile
```

At the end of the file, add this line:

```bash
export PATH=$PATH:/usr/local/go/bin
```

Now save and close the file, the source it

```bash
$ source ~/.profile
```

Now, check that you can run go commands with this command, you should see it output your version of go

```bash
$ go version
```

Next, we need to se the $GOPATH environmental variable - I'm going to set mine to /usr/local, but you can set it wherever you would like your go packages to be installed.

```bash
export GOPATH=/usr/local
```

## Installing the helper

Alright, now we're ready to install the k8s-oidc-helper.  Run this command:

```bash
$ go get github.com/micahhausler/k8s-oidc-helper
```

(Don't fret if you do not see any output, this is normal).

Once it finishes running, check that the helper was installed correctly with:

```bash
$ k8s-oidc-helper --version
```

And it should display the version of the helper.

## Configuring the helper

Now, you'll need to download something from 1Password. If you do not have access to the Operation Code 1Password, reach out to the Project lead, seargent, or any of the maintainers for information. Once you are in 1Password look for a credential called "oauth-oc".

That credential contains a file called client_secret_(...)apps.googleusercontent.com.json. Download this file to your local workstation.  I like to save it as "client_secret.json". Now run the helper, passing it this config file.

```bash
$ k8s-oidc-helper -c path/to/client_secret.json
```

If it works correctly, it will tell you to open a url in your browser. Open that url - log in to or select your operation.org account if necessary - and copy the code that is displayed, then paste it next to the prompt "Enter the code Google gave you:"

Copy the output that starts with "#Add the following to your ~/.kube/config".

## Configuring Kubernetes

Now we'll use this to configure access to Operation Code's Kubernetes cluster.  

Create a ~/.kube directory

```bash
$ mkdir ~/.kube
```

Now create a file at ~/.kube/config

```bash
$ vim ~/.kube/config
```

And paste in the content you just copied when you ran the k8s-oidc-helper.

Save and close the file.

Alright - we're almost there! First, run a couple of commands to further configure Kubernetes:

```bash
$ kubectl config set-context op-code-prod --cluster k8s.operationcode.org --user nell@operationcode.org
$ kubectl config use-context op-code-prod
```

Now, head back to 1Password and look for a note called "Kubernetes Cluster CA". Copy the content of that note and open your kube config file.

```bash
$ vim ~/.kube/config
```

And replace this line:

```bash
clusters: []
```

With this line:

```bash
clusters:
```

Then, directly after that line, paste the contents of the note you just copied from 1Password.

Save and close the file, then run this command:

```bash
$ kubectl get pods -n operationcode
```

After a few seconds, you should see a list of running Kubernetes pods including operationcode-backend, operationcode-frontend, and more!


