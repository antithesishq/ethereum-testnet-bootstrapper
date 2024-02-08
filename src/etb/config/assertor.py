from typing import List, Optional, Dict, Any
from dataclasses import dataclass

# pyyaml
def serialize_to_yaml(data_class_instance):
    """Serialize a data class instance to YAML with custom handling."""
    def convert_to_serializable(obj):
        """Convert non-serializable fields to serializable format."""
        if isinstance(obj, datetime.timedelta):
            return str(obj)
        elif isinstance(obj, (list, dict, str, int, float, bool, type(None))):
            return obj
        elif hasattr(obj, '__dict__'):
            return {k: convert_to_serializable(v) for k, v in asdict(obj).items()}
        return str(obj)  # Fallback for unsupported types

    data = convert_to_serializable(data_class_instance)
    return yaml.dump(data, allow_unicode=True, sort_keys=False)

@dataclass
class ClientConfig:
    name: str
    consensus_url: str
    consensus_headers: Dict[str, str]
    execution_url: str
    execution_headers: Dict[str, str]

@dataclass
class ServerConfig:
    port: str
    host: str
    read_timeout: str
    write_timeout: str
    idle_timeout: str

@dataclass
class FrontendConfig:
    enabled: bool
    debug: bool
    pprof: bool
    minify: bool
    site_name: str

@dataclass
class WebConfig:
    server: Optional[ServerConfig]
    frontend: Optional[FrontendConfig]

@dataclass
class NamesConfig:
    inventory_yaml: str
    inventory_url: str
    inventory: Dict[str, str]

@dataclass
class TestConfig:
    name: str
    disable: bool
    timeout: str 
    config: Dict[str, Any]
    config_vars: Dict[str, str]
    tasks: List[Any]
    cleanup_tasks: List[Any]

@dataclass
class ExternalConfig:
    file: str
    name: str
    timeout: Optional[str]
    config: Dict[str, Any]
    config_vars: Dict[str, str]

@dataclass
class AssertorConfig:
    endpoints: List[ClientConfig]
    web: Optional[WebConfig]
    validator_names: Optional[NamesConfig]
    global_vars: Dict[str, Any]
    tests: List[Optional[TestConfig]]
    external_tests: List[Optional[ExternalConfig]]

    def to_yaml(self, filename: str):
        with open(filename, 'w') as f:
            f.write(serialize_to_yaml(self))
