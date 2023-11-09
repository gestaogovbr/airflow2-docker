# cat <<EOF > airflow_local_settings.py
import yaml
from datetime import timedelta

from airflow.models import Variable
from airflow.exceptions import AirflowClusterPolicyViolation

ALLOWED_OWNERS = "team_contacts"


def dag_policy(dag):
    # Set task instances allowed concurrently max 8
    dag.max_active_tasks = (
        8
        if not dag.max_active_tasks or dag.max_active_tasks > 8
        else dag.max_active_tasks
    )

    # Set dag concurrency max to 1
    dag.max_active_runs = 1

    # Set dagrun_timeout max to 1 day
    dag.dagrun_timeout = (
        timedelta(days=1)
        if not dag.dagrun_timeout or dag.dagrun_timeout > timedelta(days=1)
        else dag.dagrun_timeout
    )

    # Check if owner exists
    owner = dag.default_args.get("owner", "")
    owner_dag_list = owner.split(",")
    # Keep only non-space items and strip outer spaces
    owner_dag_filtered_list = [
        item.lstrip().rstrip() for item in owner_dag_list if not item.isspace()
    ]
    if not owner_dag_filtered_list:
        raise AirflowClusterPolicyViolation("Missing DAG default_arg `owner`.")

    # Check if owner is allowed
    owner_allowed_yaml = yaml.safe_load(Variable.get(ALLOWED_OWNERS))
    owner_allowed_list = [
        member["airflow"]
        for member in owner_allowed_yaml["team"]
        if member.get("airflow", None)
    ]
    if not all(item in owner_allowed_list for item in owner_dag_filtered_list):
        raise AirflowClusterPolicyViolation(
            f"One of owner(s) {owner_dag_filtered_list} not in Airflow Variable {ALLOWED_OWNERS}"
        )

    # Check if dag has tags
    if not dag.tags:
        raise AirflowClusterPolicyViolation(
            f"DAG has no tags. At least one tag required."
        )
# EOF