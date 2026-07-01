"""
Interface commune pour tous les collecteurs de bourses.
Chaque nouvelle source implémente BaseCollector et remplace uniquement collect().
"""
from __future__ import annotations
import logging
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from models.scholarship import ScholarshipModel

logger = logging.getLogger("pipeline.collector")


@dataclass
class CollectorConfig:
    name: str
    base_url: str
    rate_limit_seconds: float = 2.0   # délai entre requêtes
    timeout_seconds: int = 15
    max_retries: int = 3
    headers: dict = field(default_factory=lambda: {
        "User-Agent": "Mozilla/5.0 (compatible; FlyAI-Bot/1.0; +https://flyai.app)"
    })


class BaseCollector(ABC):
    """
    Classe de base pour tous les collecteurs.
    Fournit : session HTTP avec retry, rate limiting, logging.
    Chaque sous-classe implémente uniquement collect().
    """

    def __init__(self, config: CollectorConfig):
        self.config = config
        self.logger = logging.getLogger(f"pipeline.collector.{config.name}")
        self._session = self._build_session()
        self._collected: list = []
        self._errors: list = []

    def _build_session(self) -> requests.Session:
        session = requests.Session()
        retry = Retry(
            total=self.config.max_retries,
            backoff_factor=1.5,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        adapter = HTTPAdapter(max_retries=retry)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        session.headers.update(self.config.headers)
        return session

    def get(self, url: str, **kwargs) -> requests.Response:
        """HTTP GET avec rate limiting et timeout automatiques."""
        time.sleep(self.config.rate_limit_seconds)
        return self._session.get(url, timeout=self.config.timeout_seconds, **kwargs)

    @abstractmethod
    def collect(self) -> list:
        """
        Collecte les bourses depuis la source.
        Retourne une liste de ScholarshipModel.
        Une erreur sur cette méthode NE doit PAS crasher le pipeline.
        """
        ...

    def run(self) -> list:
        """Point d'entrée sécurisé — absorbe les exceptions."""
        self.logger.info("Démarrage collecteur : %s", self.config.name)
        try:
            results = self.collect()
            self.logger.info("%s : %d bourses collectées", self.config.name, len(results))
            return results
        except Exception as exc:
            err = f"{self.config.name}: {type(exc).__name__}: {exc}"
            self._errors.append(err)
            self.logger.error("Erreur collecteur %s : %s", self.config.name, exc)
            return []

    @property
    def errors(self) -> list:
        return self._errors
