Terraform을 이용한 AWS 3-Tier Architect 구축

- 구성 내용 -
1. VPC 1개
2. Subnet 6개(Public2, Private2, DB2)
3. IGW, NAT GW 각 1개, NAT GW를 위한 고정 IP 1개
4. ALB 1개, ALB 로그 보관용 S3 1개
5. SG 3개(ALB, Pub, Pri)
6. EC2 3개(Bastion1, Web2)

* ec2 user_data 옵션 적용 실패 오류 발생 > apache 설치 실패로 인한 target group health check 실패 > aws 콘솔에서 직접 apache 설치 후 확인 성공
* user_data 옵션 확인 필요.