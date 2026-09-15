from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import (
    InternetGateway,
    NATGateway,
    RouteTable,
    ELB
)
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.onprem.client import Client

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.5",
    "splines": "ortho",
}

with Diagram(
    "Infraestrutura em Nuvem",
    show=True,
    filename="infraestrutura_nuvem",
    direction="TB"
):

    cliente = Client("Cliente")

    with Cluster("AWS Region"):

        with Cluster("VPC - 10.0.0.0/20"):

            alb = ELB("ALB FRONT")
            alb2 = ELB("ALB BACK")

            with Cluster("Availability Zone - A"):
                with Cluster("Public subnet\n10.0.1.0/24"):
                    front_a = EC2("Front-end A")
                    nat = NATGateway("NAT Gateway")

                with Cluster("Private subnet\n10.0.3.0/24"):
                    back_a = EC2("Back-end A")

                with Cluster("Private subnet\n10.0.5.0/24"):
                    db = RDS("Banco de dados")

            with Cluster("Availability Zone - B"):
                with Cluster("Public subnet\n10.0.2.0/24"):
                    front_b = EC2("Front-end B")

                with Cluster("Private subnet\n10.0.4.0/24"):
                    back_b = EC2("Back-end B")

    bucket = S3("Bucket S3\n(Bronze / Silver / Gold)")

    # -------- Conexões --------
    cliente >> Edge(color="black") >> alb

    alb >> Edge(color="black") >> [front_a, front_b]

    front_a >> Edge(color="black") >> alb2
    front_b >> Edge(color="black") >> alb2

    alb2 >> Edge(color="black") >> back_a
    alb2 >> Edge(color="black") >> back_b

    back_a >> Edge(color="black") >> db
    back_b >> Edge(color="black") >> db

    back_a >> Edge(color="black") >> bucket
    back_b >> Edge(color="black") >> bucket