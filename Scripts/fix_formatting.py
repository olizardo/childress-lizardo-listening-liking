path = '/home/omarlizardo/.config/agents/AGENTS.md'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('zout.writestr(fname, data)```', 'zout.writestr(fname, data)\n```')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
