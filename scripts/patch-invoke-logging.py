import sys

def main():
    path = 'next/src/lib/agents/invoke.ts'
    with open(path, 'r') as f:
        text = f.read()

    # 1. Log start event to console
    old = '''safeEnqueue({
        type: "start",
        bin: bin!,
        argv,
        promptBytes: Buffer.byteLength(opts.prompt, "utf8"),
      });'''
    new = '''safeEnqueue({
        type: "start",
        bin: bin!,
        argv,
        promptBytes: Buffer.byteLength(opts.prompt, "utf8"),
      });
      console.log(`[agent-start] bin=${bin!} argv=${JSON.stringify(argv)} promptBytes=${Buffer.byteLength(opts.prompt, "utf8")}`);'''
    text = text.replace(old, new)

    # 2. Log every stdout line received (before parsing)
    old = 'for (const part of parse(line)) {'
    new = 'console.log(`[agent-stdout] ${line}`);\n          for (const part of parse(line)) {'
    text = text.replace(old, new)

    # 3. Log done event to console
    old = 'child.on("close", (code) => {'
    new = 'child.on("close", (code) => {\n        console.log(`[agent-close] code=${code}`);'
    text = text.replace(old, new)

    # 4. Log error events to console
    old = 'child.on("error", (err) => {'
    new = 'child.on("error", (err) => {\n        console.error(`[agent-error] ${err.message}`);'
    text = text.replace(old, new)

    with open(path, 'w') as f:
        f.write(text)
    print('Patched invoke.ts for detailed logging')

if __name__ == '__main__':
    main()
