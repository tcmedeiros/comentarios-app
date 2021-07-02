## Introdução

Foi escolhido realizar todas as atividades utilizando ferramentas da AWS Services. Dentre as ferramentas utilizadas estão **CodeCommit**, **CodePipeline**, **CodeBuild**, **ECR**, **VPC**, **SNS**, **ECS**, **CloudWatch** e **EC2**.

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

Na pasta *app* fica os arquivos de código fonte da aplicação. Os arquivos *buildspec.yml* e *Dockerfile* são arquivos utilizados na configuração da esteira CI/CD. Apesar destes arquivos estarem dentro do repositório de código fonte, é de entendimento que o ideal é que estivesse apartado onde somente os resposáveis pela esteira tivesse acesso, como por exemplo o **S3**.

## Pipeline

Para realização do pipeline foi utilizado o **CodePipeline** e criado o pipeline *comentarios-pipeline*. O pipeline foi dividido em 3 fases:

* Source
* Build
* Deploy

### Source

Nessa fase é feito um clone do repositório de código no **CodeCommit**. Foi configurado um evento pelo **CloudWatch** que funciona como um webhook para que a cada modificação no branch *dev* este pipeline seja iniciado. Segue abaixo uma imagem da fase de source:

![image](https://user-images.githubusercontent.com/8555820/124122474-82195500-da4c-11eb-8f31-f82ce21d1ea4.png)

### Build

A fase de build parte do princípio que já estão no path da pipeline os arquivos obtidos pela fase de source. Nessa fase entra em cena o **CodeBuild**, onde foid criado o build *comentarios-build*, que executa as instruções que estão no *buildspec.yml*. Foram configuradas duas variáveis de ambiente para a execução do build: AWS_ACCOUNT_ID (id da conta aws utilizada) e IMAGE_NAME (nome da imagem que será gerada com a aplicação). Principalmente AWS_ACCOUNT_ID é uma informação segura e não deve ficar em código. Segue o código do *buildspec.yml*:

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

Segue também uma imagem com algumas execuções do **CodeBuild**:

![image](https://user-images.githubusercontent.com/8555820/124125695-4e402e80-da50-11eb-99b0-2fd861a0e43e.png)


### Deploy

A fase de deploy parte do princípio que já está no path da pipeline o arquivo com informações na imagem da aplicação. A partir deste arquivo é buscado a imagem *comentarios-app* no registry privado do **ECR**. Segue uma imagem do **ECR**:

![image](https://user-images.githubusercontent.com/8555820/124126750-62386000-da51-11eb-9965-734f0233b7bd.png)

Com a imagem buscada é feito um deploy para o serviço *comentarios-ecs-service* no **ECS**.

## Redes e Segurança

Para gerenciamento de redes foi utilizado o **VPC**. Junto a **VPC** criada com o nome *comentarios-vpc*, foram criadas duas *subnets* públicas. É de entendimento que pelo menos uma das *subnets* fosse privada com um *NAT Gateway* associada a ela e somente a *subnet* pública associada ao *Internet Gateway*. Segue a imagem da **VPC**:

![image](https://user-images.githubusercontent.com/8555820/124129078-cc520480-da53-11eb-99dd-da02b0585cc6.png)


Segue a imagem das *subnets*:

![image](https://user-images.githubusercontent.com/8555820/124128887-957bee80-da53-11eb-886b-7468b3542d0f.png)

Por último foram criado também dois *Security Groups*. Um pra acesso de todo tráfego de instâncias dentro da própria VPC e outro com as portas 80 (API do ECS Cluster) e 8000 (ser acessado pelo Load Balancer). Segue imagem das *Security Groups*.

![image](https://user-images.githubusercontent.com/8555820/124129364-19ce7180-da54-11eb-8ade-ddf07af66e15.png)

> ATENÇÃO: Não foi tomado como objetivo nesta prova realizar melhores práticas de configurações de rede ou segurança, tão pouco entrar em detalhes de granularidade de papéis e políticas criadas na aws para realização desta tarefa.


# Hospedagem e Acesso da Aplicação

Na hospedagem de aplicações utilizamos o **ECS**. Foi criado um cluster com dois nós e chamado *ecs-cluster*. Criamos uma *Task Definition* chamada *comentarios-taskdefinition* baseada em nós de instâncias **EC2** configurada com a imagem do **ECR** *comentarios-app* na porta 8000. Segue a imagem do *ecs-cluster*:

![image](https://user-images.githubusercontent.com/8555820/124130440-299a8580-da55-11eb-8c77-2bad18c2b710.png)

Também foi criado um serviço chamado *comentarios-ecs-service* utilizando a *Task Definition* já citada com um *autoscaling* de mínimo 1 e máximo 3. Criamos um *Application Load Balancer* ouvindo da porta 80 e redirecionando para porta 8000 dos conteineres associados ao serviço *comentarios-ecs-service*, forma que o acesso público pudesse ser feito através dele. Segue a imagem do *Target Group* do *Load Balancer*:

![image](https://user-images.githubusercontent.com/8555820/124131645-631fc080-da56-11eb-8824-400f5b9d8c25.png)

Segue também uma imagem da aplicação funcionando:

![image](https://user-images.githubusercontent.com/8555820/124131859-95c9b900-da56-11eb-96d8-1396c909c6e6.png)


# Monitoramento

O monitoramento foi feito com apoio do **CloudWatch** em alguns pontos da esteira e no cluster. Com o consumo dos recursos atingindo o limite estabelecido, é informado por email pelo **SNS** para que ações proativas sejam tomadas. foi criado o painel *comentarios-dash* como mostra a imagem a seguir:

![image](https://user-images.githubusercontent.com/8555820/124270455-9cb60180-db12-11eb-94ed-2e66cb836201.png)


# Considerações Finais

Apesar de utilizado **ECS** e ele atender bem a diversas necessidades, é entendido que o **EKS** é uma ferramenta bem mais robusta e programável (se tratando de Iac), e seria de gosto que fosse utilizado se houvesse mais tempo para se dedicar a esta tarefa. Também seria de gosto que utiliza-se um *Load Balancer* interno e a exposição dos serviços fossem feitas através do *API Gateway*.


