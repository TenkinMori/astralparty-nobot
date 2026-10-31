// Probe.cs —— 自动定位 RequestStartGameC2S 的调用点
//
// 输出格式（每行一个目标）：
//   TARGET\t<类型全名>\t<方法名>\t<IL偏移>\t<常量值>
//
// 适配性：不依赖编译器生成的 lambda 名字，而是扫描所有方法体，
// 找 call/callvirt RequestStartGameC2S 前面的 ldc.i4 常量。
using System;
using System.Linq;
using Mono.Cecil;
using Mono.Cecil.Cil;

class Probe
{
    static void Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("用法: Probe <dll路径>");
            Environment.Exit(2);
        }

        AssemblyDefinition asm = null;
        try
        {
            asm = AssemblyDefinition.ReadAssembly(args[0]);
        }
        catch (Exception e)
        {
            Console.Error.WriteLine("读取失败: " + e.Message);
            Environment.Exit(3);
        }
        if (asm == null)
        {
            Console.Error.WriteLine("程序集为空");
            Environment.Exit(4);
        }

        var all = asm.MainModule.Types
            .SelectMany(t => new[] { t }.Concat(t.NestedTypes))
            .ToList();

        int found = 0;

        foreach (var t in all)
        {
            if (!t.HasMethods) continue;
            foreach (var m in t.Methods)
            {
                if (!m.HasBody) continue;
                var ins = m.Body.Instructions.ToList();

                for (int i = 0; i < ins.Count; i++)
                {
                    var op = ins[i];
                    if (!(op.Operand is MethodReference mr)) continue;
                    if (mr.Name != "RequestStartGameC2S") continue;

                    // 向前找 ldc.i4（1~4 条内）
                    for (int k = i - 1; k >= Math.Max(0, i - 4); k--)
                    {
                        int? v = ConstVal(ins[k]);
                        if (v == null) continue;

                        // Occurrence：该方法里这是第几个 "RequestStartGameC2S 前的常量"
                        int occ = CountOccurrence(ins, i, v.Value);
                        Console.WriteLine("TARGET\t{0}\t{1}\t{2}\t{3}",
                            t.FullName, m.Name, ins[i].Offset.ToString("X4"), v.Value);
                        found++;
                        break;
                    }
                }
            }
        }

        Console.Error.WriteLine("共找到 {0} 个 RequestStartGameC2S 调用点", found);
    }

    static int? ConstVal(Instruction i)
    {
        switch (i.OpCode.Code)
        {
            case Code.Ldc_I4_M1: return -1;
            case Code.Ldc_I4_0:  return 0;
            case Code.Ldc_I4_1:  return 1;
            case Code.Ldc_I4_2:  return 2;
            case Code.Ldc_I4_3:  return 3;
            case Code.Ldc_I4_4:  return 4;
            case Code.Ldc_I4_5:  return 5;
            case Code.Ldc_I4_6:  return 6;
            case Code.Ldc_I4_7:  return 7;
            case Code.Ldc_I4_8:  return 8;
            case Code.Ldc_I4_S:  return (sbyte)i.Operand;
            case Code.Ldc_I4:    return (int)i.Operand;
            default: return null;
        }
    }

    // 统计：在这个调用点之前，同一方法里已经出现过多少个「值为 v 的 ldc.i4 且紧跟 RequestStartGameC2S」
    static int CountOccurrence(System.Collections.Generic.List<Instruction> ins, int callIdx, int v)
    {
        int n = 0;
        for (int i = 0; i < callIdx; i++)
        {
            if (!(ins[i].Operand is MethodReference mr)) continue;
            if (mr.Name != "RequestStartGameC2S") continue;
            for (int k = i - 1; k >= Math.Max(0, i - 4); k--)
            {
                int? kv = ConstVal(ins[k]);
                if (kv == null) continue;
                if (kv.Value == v) n++;
                break;
            }
        }
        return n + 1;
    }
}