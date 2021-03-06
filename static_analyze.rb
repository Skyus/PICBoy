#!/usr/bin/env ruby

# Analyze Core.c to see a rough estimate of instructions/gameboy instruction
# Requires clang, llvm (on macOS brew install llvm and symlink llc to /usr/local/bin)

puts "Core.c performance static analyzer"

`rm Core.ll Core.s`

for level in ["0", "2"]
    puts "\nAnalyzing at optimization level #{level}...\n\n"
    `clang -S -emit-llvm -O#{level} Core.c`
    `llc Core.ll -march=mipsel -o Core.s 2> /dev/null`

    enable = false

    instructions = {}
    cbs = []

    instructions["Core_cycle"] = 0

    File.readlines("Core.s").each do
        |line|
        if line.include? "execute:"
            enable = true
        elsif line == "	.size	execute, 1024"
            enable = false
        end

        if enable
            matches = /\s*\.4byte\s*([^ ]+)\s*\n/.match(line)
            if matches != nil
                instructions[matches[1]] = 0
            end
        end
    end

    enable = false

    File.readlines("Core.s").each do
        |line|
        if line.include? "cbExecute:"
            enable = true
        elsif line == "	.size	cbExecute, 1024"
            enable = false
        end

        if enable
            matches = /\s*\.4byte\s*([^ ]+)\s*\n/.match(line)
            if matches != nil
                instructions[matches[1]] = 0
                cbs << matches[1]
            end
        end
    end

    current = nil

    File.readlines("Core.s").each do
        |line|
        matches = /^([^$#].*?):\s*/.match(line)
        if matches != nil
            if instructions.key?(matches[1])
                current = matches[1]
            else
                current = nil
            end
        else
            matches = /^\s*([.#$].*)/.match(line)
            if matches == nil && current != nil
                instructions[current] += 1
            end
        end
    end

    core_cycle = instructions["Core_cycle"]
    instructions.delete("Core_cycle")

    cb = instructions["cb"]
    instructions.delete("cb")

    instructions.each do
        |key, value|
        puts "%10s: %3i" % [key, value]
    end

    puts "cb: #{cb}, Core_cycle: #{core_cycle}"
    puts "\nO#{level} average: #{core_cycle + (instructions.inject(0.0) { |sum, value| sum + value[1] + (cbs.include?(value[0])? cb : 0) } / instructions.count)}\n\n"
end