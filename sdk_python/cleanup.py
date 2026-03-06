#!/usr/bin/env python3
"""Cleanup infrastructure created by sdk_python/deploy.py."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any, Dict, Optional

import boto3
from botocore.exceptions import ClientError


def load_state(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"State file not found: {path}")
    return json.loads(path.read_text())


def save_state(path: Path, state: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True))


class Cleaner:
    def __init__(self, state: Dict[str, Any], region: str, profile: Optional[str], endpoint_url: Optional[str]) -> None:
        self.state = state
        session = boto3.Session(profile_name=profile, region_name=region)
        kwargs = {"endpoint_url": endpoint_url} if endpoint_url else {}
        self.ec2 = session.client("ec2", **kwargs)
        self.ecr = session.client("ecr", **kwargs)
        self.ecs = session.client("ecs", **kwargs)
        self.iam = session.client("iam", **kwargs)
        self.logs = session.client("logs", **kwargs)
        self.elbv2 = session.client("elbv2", **kwargs)
        self.apigw = session.client("apigateway", **kwargs)

    def run(self) -> None:
        self.delete_api_gateway()
        self.delete_ecs_service_and_task()
        self.delete_load_balancer_resources()
        self.delete_ecs_core()
        self.delete_ecr()
        self.delete_network()

    def delete_api_gateway(self) -> None:
        self._safe_call(self.apigw.delete_rest_api, restApiId=self.state.get("rest_api_id"))
        self._safe_call(self.apigw.delete_vpc_link, vpcLinkId=self.state.get("vpc_link_id"))

    def delete_ecs_service_and_task(self) -> None:
        cluster = self.state.get("ecs_cluster_name")
        service = self.state.get("ecs_service_name")

        if cluster and service:
            self._safe_call(self.ecs.update_service, cluster=cluster, service=service, desiredCount=0)
            self._safe_call(self.ecs.delete_service, cluster=cluster, service=service, force=True)
            self._wait_service_deleted(cluster, service)

        task_arn = self.state.get("task_definition_arn")
        if task_arn:
            self._safe_call(self.ecs.deregister_task_definition, taskDefinition=task_arn)

    def delete_load_balancer_resources(self) -> None:
        self._safe_call(self.elbv2.delete_listener, ListenerArn=self.state.get("listener_arn"))
        self._safe_call(self.elbv2.delete_load_balancer, LoadBalancerArn=self.state.get("load_balancer_arn"))
        self._wait_load_balancer_deleted(self.state.get("load_balancer_arn"))
        self._safe_call(self.elbv2.delete_target_group, TargetGroupArn=self.state.get("target_group_arn"))

        sg = self.state.get("fargate_security_group_id")
        if sg:
            self._safe_call(self.ec2.delete_security_group, GroupId=sg)

    def delete_ecs_core(self) -> None:
        cluster = self.state.get("ecs_cluster_name")
        if cluster:
            self._safe_call(self.ecs.delete_cluster, cluster=cluster)

        log_group = self.state.get("log_group_name")
        if log_group:
            self._safe_call(self.logs.delete_log_group, logGroupName=log_group)

        exec_role = self.state.get("task_execution_role_name")
        task_role = self.state.get("task_role_name")

        if exec_role:
            self._safe_call(
                self.iam.detach_role_policy,
                RoleName=exec_role,
                PolicyArn="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
            )
            self._safe_call(self.iam.delete_role, RoleName=exec_role)

        if task_role:
            self._safe_call(self.iam.delete_role, RoleName=task_role)

    def delete_ecr(self) -> None:
        repo_name = self.state.get("ecr_repository_name")
        if repo_name:
            self._safe_call(self.ecr.delete_repository, repositoryName=repo_name, force=True)

    def delete_network(self) -> None:
        # Route table associations and route table
        for assoc_id in self.state.get("route_association_ids", []):
            self._safe_call(self.ec2.disassociate_route_table, AssociationId=assoc_id)

        rt_id = self.state.get("route_table_id")
        if rt_id:
            self._safe_call(self.ec2.delete_route_table, RouteTableId=rt_id)

        # Subnets
        for subnet_id in self.state.get("subnet_ids", []):
            self._safe_call(self.ec2.delete_subnet, SubnetId=subnet_id)

        # IGW detach + delete
        igw_id = self.state.get("internet_gateway_id")
        vpc_id = self.state.get("vpc_id")
        if igw_id and vpc_id:
            self._safe_call(self.ec2.detach_internet_gateway, InternetGatewayId=igw_id, VpcId=vpc_id)
        if igw_id:
            self._safe_call(self.ec2.delete_internet_gateway, InternetGatewayId=igw_id)

        if vpc_id:
            self._safe_call(self.ec2.delete_vpc, VpcId=vpc_id)

    def _safe_call(self, fn, **kwargs):
        clean_kwargs = {k: v for k, v in kwargs.items() if v}
        if not clean_kwargs:
            return
        try:
            fn(**clean_kwargs)
        except ClientError:
            pass

    def _wait_service_deleted(self, cluster: str, service: str, timeout: int = 300) -> None:
        start = time.time()
        while time.time() - start < timeout:
            try:
                svc = self.ecs.describe_services(cluster=cluster, services=[service])["services"]
                if not svc:
                    return
                if svc[0].get("status") == "INACTIVE":
                    return
            except ClientError:
                return
            time.sleep(5)

    def _wait_load_balancer_deleted(self, lb_arn: Optional[str], timeout: int = 300) -> None:
        if not lb_arn:
            return
        start = time.time()
        while time.time() - start < timeout:
            try:
                self.elbv2.describe_load_balancers(LoadBalancerArns=[lb_arn])
            except ClientError:
                return
            time.sleep(5)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cleanup stack deployed via sdk_python/deploy.py")
    parser.add_argument("--state-file", required=False)
    parser.add_argument("--project-name", default="crud-api")
    parser.add_argument("--environment", default="dev")
    parser.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    parser.add_argument("--profile", default=os.environ.get("AWS_PROFILE"))
    parser.add_argument("--endpoint-url", default=None)
    parser.add_argument("--keep-state-file", action="store_true", default=False)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.state_file:
        state_path = Path(args.state_file)
    else:
        state_path = Path(__file__).resolve().parent / ".state" / f"{args.project_name}-{args.environment}.json"

    state = load_state(state_path)
    cleaner = Cleaner(state=state, region=args.region, profile=args.profile, endpoint_url=args.endpoint_url)
    cleaner.run()

    if args.keep_state_file:
        state["deleted_at"] = time.time()
        save_state(state_path, state)
    else:
        state_path.unlink(missing_ok=True)

    print("Cleanup complete")


if __name__ == "__main__":
    main()
