from typing import List, Optional, Dict, Any
from dataclasses import dataclass, asdict
from ruamel.yaml.comments import CommentedMap as omap

def serialize_to_yaml(data_class_instance):
    """Serialize a data class instance to YAML with custom handling."""
    def convert_to_serializable(obj):
        """Convert non-serializable fields to serializable format."""
        if isinstance(obj, (str, int, float, bool, type(None))):
            return obj
        elif isinstance(obj, (list)):
            return [convert_to_serializable(v) for v in obj if v is not None]
        elif isinstance(obj, (dict)):
            return {k: convert_to_serializable(v) for k, v in obj.items() if v is not None}
        elif hasattr(obj, '__dict__'):
            return {k: convert_to_serializable(v) for k, v in asdict(obj).items() if v is not None}
        
        print(f"Unsupported type: {type(obj)} {str(obj)}") 
        return str(obj)  # Fallback for unsupported types

    data = convert_to_serializable(data_class_instance)
    print("data: ", data)
    return data

@dataclass
class ClientConfig:
    name: str
    consensus_url: str
    execution_url: str
    consensus_headers: Optional[Dict[str, str]] = None
    execution_headers: Optional[Dict[str, str]] = None

@dataclass
class ServerConfig:
    port: str
    host: str
    read_timeout: Optional[str] = None
    write_timeout: Optional[str] = None
    idle_timeout: Optional[str] = None

@dataclass
class FrontendConfig:
    enabled: bool
    debug: Optional[bool] = None
    pprof: Optional[bool] = None
    minify: Optional[bool] = None
    site_name: Optional[str] = None

@dataclass
class WebConfig:
    server: Optional[ServerConfig] = None
    frontend: Optional[FrontendConfig] = None

@dataclass
class NamesConfig:
    inventory_yaml: Optional[str] = None
    inventory_url: Optional[str] = None
    inventory: Optional[Dict[str, str]] = None

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
class ExternalTests:
    name: str
    file: str
    timeout: Optional[str] = None
    config: Optional[Dict[str, Any]] = None
    config_vars: Optional[Dict[str, str]] = None

@dataclass
class AssertorConfig:
    endpoints: List[ClientConfig]
    web: Optional[WebConfig] = None
    validator_names: Optional[NamesConfig] = None
    global_vars: Optional[Dict[str, Any]] = None
    tests: Optional[List[Optional[TestConfig]]] = None
    external_tests: Optional[List[Optional[ExternalTests]]] = None

    def to_yaml(self, filename: str):
        with open(filename, 'w') as f:
            f.write(serialize_to_yaml(self))
