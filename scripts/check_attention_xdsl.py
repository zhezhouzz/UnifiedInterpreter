import sys
from pathlib import Path

from xdsl.parser import Parser

from attention_dialects import context

for filename in sys.argv[1:]:
    module = Parser(context(), Path(filename).read_text(), filename).parse_module()
    module.verify()
    print(filename, len(tuple(module.walk())), "operations parsed")
