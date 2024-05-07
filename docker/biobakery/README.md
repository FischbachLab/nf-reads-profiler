# Updating the image on ECR

## Building and tagging

```bash
docker build --no-cache -t 458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1 .
# docker tag biobakery/workflows:maf-20221028-a1 458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1
```

## Pushing to ECR

```bash
docker push 458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1
```

## Troubleshooting

If the push doesn not work. Try the following command on your terminal:

```bash
sudo yum install -y amazon-efs-utils amazon-ecr-credential-helper
mkdir ${HOME}/.docker
echo '{"credsStore": "ecr-login"}' > ${HOME}/.docker/config.json
```

now retry the push command.
