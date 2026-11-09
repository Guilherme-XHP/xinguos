"""xinguos-foco: daemon de prioridade e tempo de uso (serviço de usuário do systemd)."""
import asyncio
import logging
import sys

from .servico import rodar


def main() -> int:
    logging.basicConfig(level=logging.INFO, stream=sys.stderr, format="%(levelname)s %(name)s: %(message)s")
    return asyncio.run(rodar())


if __name__ == "__main__":
    sys.exit(main())
