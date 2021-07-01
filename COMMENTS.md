## Introdução

Foi escolhido realizar todas as atividades utilizando ferramentas da AWS Services. Dentre as ferramentas utilizadas estão **CodeCommit**, **CodePipeline**, **CodeBuild**, **ECR**, **VPC**, **ECS**, **CloudWatch** e **EC2**.

## O código

No código da aplicação foi adicionado um enpoint para utilização do health check.

```python
@app.route('/health-check')
def api_health_check():
    message = 'its ok!'
    response = {
            'status': 'SUCCESS',
            'message': message,
            }
    return jsonify(response)
```


## Repositório de Código Fonte

O primeiro passo para uma esteira CI/CD é o repositório de códigos. Para essa etapa foi utilizado o **CodeCommit** e criado o repositório *comentarios-app*. Também foi criado o branch *dev*, o qual foi utilizado para realização de toda essa prova. Segue abaixo uma imagem do repositório:

![image](https://user-images.githubusercontent.com/8555820/124117838-f81abd80-da46-11eb-94bb-45e955db83e9.png)

> ATENÇÃO: Não foi tomado como objetivo nesta prova realizar a esteira completa até produção. Para fins de prova de conhecimento realizamento a tarefa simulando somente um ambiente.

Na pasta **app** fica os arquivos de código fonte da aplicação. Os arquivos **buildspec.yml** e **Dockerfile** são arquivos utilizados na configuração da esteira CI/CD. Apesar destes arquivos estarem dentro do repositório de código fonte, entendemos que o ideal é que estivesse apartado onde somente os resposáveis pela esteira tivesse acesso, como por exemplo o **S3**.

## Pipeline

Para realização do pipeline foi utilizado o **CodePipeline** e criado o pipeline *comentarios-pipeline*. O pipeline foi dividido em 3 fases:

* Source
* Build
* Deploy

### Source

Nessa fase é feito um clone do repositório de código no **CodeCommit**. Foi configurado um evento pelo **CloudWatch** que funciona como um webhook para que a cada modificação no branch *dev* este pipeline seja iniciado. Segue abaixo uma imagem da fase de source:

![image](https://user-images.githubusercontent.com/8555820/124122474-82195500-da4c-11eb-8f31-f82ce21d1ea4.png)

### Build

A fase de build parte do princípio que já estão no path da pipeline os arquivos obtidos pela fase de source. Nessa fase entra em cena o ***CodeBuild***, onde foid criado o build *comentarios-build*, que executa as instruções que estão no **buildspec.yml**. Foram configuradas duas variáveis de ambiente para a execução do build: AWS_ACCOUNT_ID (id da conta aws utilizada) e IMAGE_NAME (nome da imagem que será gerada com a aplicação). Principalmente AWS_ACCOUNT_ID é uma informação segura e não deve ficar em código. Segue o código do **buildspec.yml**:

```yaml
version: 0.2
    
phases:
  pre_build:
    commands:
      - echo Logando no Amazon ECR
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - echo Definindo o repositório ECR
      - ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - IMAGE=$ECR/$IMAGE_NAME
  build:
    commands:
      - echo Construindo imagem Docker
      - docker build . -t current:latest --build-arg REPO=$ECR
      - docker tag current:latest $IMAGE:$CODEBUILD_BUILD_NUMBER
      - docker tag current:latest $IMAGE:latest
  post_build:
    commands:
      - echo Enviando imagem para Repositório ERC
      - docker push $IMAGE:$CODEBUILD_BUILD_NUMBER
      - docker push $IMAGE:latest
      - printf '[{"name":"comentarios-app","imageUri":"%s"}]' $IMAGE:latest > image-to-ecs.json
artifacts:
  files: image-to-ecs.json
```

Segundo o buildspec são realizadas três etapas: pre_build, build e post_build. A etapa de pre_build loga no registry do **ECR** e realiza a montagem do caminho completo da imagem. A etapa de build constroi a imagem a partir do *Dockerfile*, passando ao *Dockerfile* o endereço pelo argumento *REPO* do registry do **ECR** na qual ele deve trabalhar. Segue o código do *Dockerfile*:

```yaml
ARG REPO

FROM $REPO/python:3

WORKDIR /usr/src/app

RUN pip install Flask
RUN pip install gunicorn

COPY app/* ./

CMD gunicorn -b 0.0.0.0 --log-level debug api:app

EXPOSE 8000
```

Foi colocado a imagem do *python:3* no registry privado da aws por que se for realizado *pull* dessa imagem do repositório público por diversas vezes, o repositório público começa a recusar as chamadas. O endereço do registry também foi passado por parametro para o *Dockerfile* para garantir que se tenha arquivos de configurações independente de regiões e contas aws. Após a geração da imagem ela é tageada com o número do build e como *latest*. A última etapa, post_build, envia as novas imagens para o registry e gera um artefado com informações da imagem para ser utilizada pela fase de deploy. Segue abaixo uma imagem da fase de build no pipeline:

![image](https://user-images.githubusercontent.com/8555820/124125353-e5f14d00-da4f-11eb-8add-0690185fa03b.png)

Segue também uma imagem com algumas execuções do ***CodeBuild***:

![image](https://user-images.githubusercontent.com/8555820/124125695-4e402e80-da50-11eb-99b0-2fd861a0e43e.png)


### Deploy

A fase de deploy parte do princípio que já está no path da pipeline o arquivo com informações na imagem da aplicação.

A primeira ação realizada é utilizar o arquivo **Dockerfile** para criação de uma imagem docker imutável, já com a aplicação dentro. Esta imagem é armazenada no repositório de imagens docker, o AWS **ECR**. Segue abaixo uma imagem do **ECR**:

![image](https://user-images.githubusercontent.com/8555820/123867030-35c2fd80-d904-11eb-8ac0-b16eab7eb519.png)

Nesta imagem podemos ver as imagens de **comentarios-app** com a aplicação e **python**, utilizada como base pelo **Dockerfile** para geração da imagem da aplicação.

Com a imagem criada, são executados os arquivos **comentarios-app-deployment.yml** e **comentarios-app-service.yml** para deploy no EKS. O arquivo **comentarios-app-deployment.yml** contém informações sobre a aplicação e a quantidade de réplicas a serem criadas. O arquivo **comentarios-app-service.yml** trabalha na criação/atualização do load balance.


# Hospedagem de Aplicações

Na hospedagem de aplicações utilizamos o **EKS**, solução AWS baseado no kubernetes. Foi de entendimento que esta é uma boa solução pela facilidade da escalabilidade de aplicações e facilidade na migração para outras soluções de nuvens e ferramentas on premise.  Segue abaixo uma imagem do cluster **EKS**:

![image](https://user-images.githubusercontent.com/8555820/123867133-58edad00-d904-11eb-9afb-ddb886f83e46.png)

Com relação aos nós do cluster, ao invés de utilizar Grupo de Nós Gerenciados (solução baseada em EC2), foi preferido o uso de Perfil do Fargate (solução baseada em ECS) para que não tivessemos preocupação com a escalabilidade dos nós. Segue abaixo uma imagem do **Perfil de Fargate**:

![image](https://user-images.githubusercontent.com/8555820/123867219-74f14e80-d904-11eb-8b9f-f6a54aa30290.png)


