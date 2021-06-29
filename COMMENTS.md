# Introdução

Foi escolhido realizar todas as atividades utilizando ferramentas da AWS Services. Dentre as ferramentas utilizadas estão **CodeCommit**, **CodePipeline**, **CodeBuild**, **ECR**, **VPC**, **EKS**, **Cloudwatch** e **API Gateway**.


# Repositório de Código Fonte

O primeiro passo para uma esteira CI/CD é o repositório de códigos. Para essa etapa utilizamos o **CodeCommit**. Segue abaixo uma imagem do repositório:

![image](https://user-images.githubusercontent.com/8555820/123844512-824d0f80-d8e9-11eb-8c1f-5fe4c9246466.png)

Na pasta **app** fica os arquivos do desenvolviemnto da aplicação. Os arquivos **buildspec.yml**, **comentarios-app-deployment.yml**, **comentarios-app-service.yml** e **Dockerfile** são arquivos utilizados na configuração da esteira CI/CD. Apesar destes arquivos estarem dentro do repositório de código fonte, entendemos que o ideal é que estivesse apartado onde somente os resposáveis pela esteira tivesse acesso, como por exemplo o **S3**.

# Pipeline

Para o pipeline de build e deploy foram utilizados o **CodePipeline** e **CodeBuild**. Segue abaixo uma imagem da pipeline:

![image](https://user-images.githubusercontent.com/8555820/123844512-824d0f80-d8e9-11eb-8c1f-5fe4c9246466.png)

O **CodePipeline** cria um webhook, onde a cada modificação no repositório de código fonte é iniciado uma execução da pipeline. Para execução do build o **CodeBuild** é acionado. Segue abaixo uma imagem do build:

![image](https://user-images.githubusercontent.com/8555820/123844512-824d0f80-d8e9-11eb-8c1f-5fe4c9246466.png)

O CodeBuild executa as instruções que estão no **buildspec.yml**. A primeira ação realizada é utilizar o arquivo **Dockerfile** para criação de uma imagem docker imutável, já com a aplicação dentro. Esta imagem é armazenada no repositório de imagens docker, o AWS **ECR**. Segue abaixo uma imagem do **ECR**:

![image](https://user-images.githubusercontent.com/8555820/123847872-719e9880-d8ed-11eb-9a22-206722c59393.png)

Nesta imagem podemos ver as imagens de **comentarios-app** com a aplicação e **python**, utilizada como base pelo **Dockerfile** para geração da imagem da aplicação.

Com a imagem criada, são executados os arquivos **comentarios-app-deployment.yml** e **comentarios-app-service.yml** para deploy no EKS. O arquivo **comentarios-app-deployment.yml** contém informações sobre a aplicação e a quantidade de réplicas a serem criadas. O arquivo **comentarios-app-service.yml** trabalha na criação/atualização do load balance.
