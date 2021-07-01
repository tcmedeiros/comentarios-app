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

# Pipeline

Para realização do pipeline foi utilizado o **CodePipeline**.
Para o pipeline de build e deploy foram utilizados o **CodePipeline** e **CodeBuild**. Segue abaixo uma imagem da pipeline:

![image](https://user-images.githubusercontent.com/8555820/123866971-1cba4c80-d904-11eb-867e-b79275261d82.png)

O **CodePipeline** cria um webhook, onde a cada modificação no repositório de código fonte é iniciado uma execução da pipeline. Para execução do build o **CodeBuild** é acionado. Segue abaixo uma imagem do build:

![image](https://user-images.githubusercontent.com/8555820/123844512-824d0f80-d8e9-11eb-8c1f-5fe4c9246466.png)

O CodeBuild executa as instruções que estão no **buildspec.yml**. A primeira ação realizada é utilizar o arquivo **Dockerfile** para criação de uma imagem docker imutável, já com a aplicação dentro. Esta imagem é armazenada no repositório de imagens docker, o AWS **ECR**. Segue abaixo uma imagem do **ECR**:

![image](https://user-images.githubusercontent.com/8555820/123867030-35c2fd80-d904-11eb-8ac0-b16eab7eb519.png)

Nesta imagem podemos ver as imagens de **comentarios-app** com a aplicação e **python**, utilizada como base pelo **Dockerfile** para geração da imagem da aplicação.

Com a imagem criada, são executados os arquivos **comentarios-app-deployment.yml** e **comentarios-app-service.yml** para deploy no EKS. O arquivo **comentarios-app-deployment.yml** contém informações sobre a aplicação e a quantidade de réplicas a serem criadas. O arquivo **comentarios-app-service.yml** trabalha na criação/atualização do load balance.


# Hospedagem de Aplicações

Na hospedagem de aplicações utilizamos o **EKS**, solução AWS baseado no kubernetes. Foi de entendimento que esta é uma boa solução pela facilidade da escalabilidade de aplicações e facilidade na migração para outras soluções de nuvens e ferramentas on premise.  Segue abaixo uma imagem do cluster **EKS**:

![image](https://user-images.githubusercontent.com/8555820/123867133-58edad00-d904-11eb-9afb-ddb886f83e46.png)

Com relação aos nós do cluster, ao invés de utilizar Grupo de Nós Gerenciados (solução baseada em EC2), foi preferido o uso de Perfil do Fargate (solução baseada em ECS) para que não tivessemos preocupação com a escalabilidade dos nós. Segue abaixo uma imagem do **Perfil de Fargate**:

![image](https://user-images.githubusercontent.com/8555820/123867219-74f14e80-d904-11eb-8b9f-f6a54aa30290.png)


