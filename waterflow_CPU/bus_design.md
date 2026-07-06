# single_cycle_CPU 项目总线设计解析

本项目采用的是一个**单主设备、内存映射、非流水化**的简单总线结构：  
CPU 在执行 `ld/st` 这类访存指令时发起总线请求，`bus_controller` 在下一周期完成对 RAM/LCD 的访问，并通过 `bus_ready` 回合拍反馈 CPU 是否可继续。

## 1. 总线参与模块

### 1.1 CPU 侧（请求发起）
位于 [CPU.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/CPU.v)

- 端口：
  - `bus_req`：有无总线请求，`MemWr | MemtoReg`
  - `bus_we`：是否写操作，等于 `MemWr`
  - `bus_addr`：访问地址，来自 ALU 结果 `alu_res`
  - `bus_wdata`：写数据，来自 `reg_rdata2`
  - `bus_rdata`：总线返回数据（来自 `bus_controller`）
  - `bus_ready`：总线完成应答
- 关键连接逻辑（同 [CPU.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/CPU.v)）：
  - `assign bus_req   = MemWr | MemtoReg;`
  - `assign bus_we    = MemWr;`
  - `assign bus_addr  = alu_res;`
  - `assign bus_wdata = reg_rdata2;`
  - `assign cpu_stall = (MemWr | MemtoReg) & (!bus_ready);`
  - `assign reg_wdata = PCtoReg ? nxt_pc : (MemtoReg ? mem_rdata : alu_res);`

> `cpu_stall` 会在总线尚未应答时阻塞 PC 与寄存器写入，这样保证访存类指令不会提前“越过”总线阶段。

### 1.2 顶层连接（总线枢纽）
位于 [main.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/main.v)

`main.v` 把 CPU 与 `bus_controller` 串接成单一系统总线通道：

- CPU -> `bus_controller`：`bus_req/we/addr/wdata`
- `bus_controller` -> CPU：`bus_rdata/ready`
- 同时给 `bus_controller` 注入 LCD 侧读源 `lcd_input`，并接收 `lcd_wr_en/lcd_wr_data` 输出。

### 1.3 总线控制器
位于 [bus_controller.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/bus_controller.v)

职责：对 CPU 请求进行抓取、译码、访问 RAM/LCD，并在完成后返回数据/ready。

内部端口和关键信号：

- `localparam [31:0] lcd_addr = 32'h7f000000;`  
  精确匹配该地址即访问 LCD；其余全部走 RAM。
- `sel_lcd = (req_addr == lcd_addr);`
- `sel_ram = (req_addr != lcd_addr);`
- `word_addr = req_addr[17:2];`
- `ram_wen = sel_ram && req_we && (state == ACCESS);`
- `bus_ready = (state == DONE);`

### 1.4 RAM 包装器
位于 [ram.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/ram.v)

`ram` 只是对 [dist_ram](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/ip/dist_ram/sim/dist_ram.v) 的一层封装，地址宽度为 16 位，数据宽度为 32 位：
- `ram_addr : [15:0]`
- `ram_wdata : [31:0]`
- `ram_wen`
- `ram_data : [31:0]`

### 1.5 指令侧不是总线的一部分
指令读取使用独立只读通道：
- `CPU.v` 内部的 `read_Instr` 模块直接实例化 `Instr_rom`（[Instr_rom.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/Instr_rom.v)）；
- 地址走 `pc[17:2]`，与数据总线无关。

## 2. 地址空间映射

### 2.1 RAM 映射
- 通过 `req_addr[17:2]` 形成 16 位字地址。
- RAM 深度为 65536×32（见 IP 配置），覆盖 16 位地址空间。
- 因为低两位被抛弃，CPU 使用的是“字地址访问”风格（每次按 4 字节对齐）。

### 2.2 LCD 映射
- 硬编码单点映射：`0x7f000000`。
- 只有 `req_addr` 完全等于该常量时才走 LCD。
  - 读：返回 `lcd_input`
  - 写：`lcd_wr_en = sel_lcd && req_we && state == ACCESS`，`lcd_wr_data = req_wdata`

### 2.3 指令ROM
- 指令ROM使用独立接口，不与系统数据总线共享 `bus_req`。
- `Instr_rom` 的地址端口是 `a[15:0]`（见 dist_rom 配置），来自 PC 的 `[17:2]`。

## 3. 时序与握手状态机

`bus_controller` 使用 `IDLE -> ACCESS -> DONE -> IDLE` 状态机（[bus_controller.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/bus_controller.v)）：

1. `IDLE`
   - 若 `bus_req=1`，抓取 `bus_we/addr/wdata` 到内部寄存器并进入 `ACCESS`
   - 未请求时保持空闲
2. `ACCESS`
   - 对 RAM/LCD 发起本周期访问
   - 读类型 `rdata <= sel_lcd ? lcd_input : ram_rdata`（组合快照后寄存）
   - 下一态 `DONE`
3. `DONE`
   - `bus_ready=1`，对 CPU 表示本次事务完成
   - 下一拍回到 `IDLE`

时钟域：全部与 `cpu_clk`（由 `cpuclk` 产生）同域。

## 4. 周期行为示意

### 4.1 Store（`st`）示例
- Cycle N：`MemWr=1`，`bus_req=1`，CPU 产生 `bus_stall=1`，PC/写使能被阻塞。
- Cycle N：总线抓取请求、进入 `ACCESS`。
- Cycle N+1：`ACCESS` 状态执行 `ram_wen`，同时 CPU 仍有 `bus_ready=0`。
- Cycle N+2：`DONE`，`bus_ready=1`，CPU 可退出 stall 进入下一条指令抓取（无数据回读）。

### 4.2 Load（`ld`）示例
- Cycle N：`MemtoReg=1`，同样 `bus_req=1`、stall。
- Cycle N：总线抓取请求。
- Cycle N+1：读数据 `rdata` 被锁存。
- Cycle N+2：`DONE`，CPU 释放 stall，`mem_rdata` 在这周期可用于回写 `reg_wdata`。

> 当前实现中 `cpu_stall` 的门控同时覆盖 `MemWr` 和 `MemtoReg`，所以 Store 也会引入一个等待周期。

## 5. 设计特点与取舍

### 优点
- 结构非常简洁：CPU 与外设分层清晰，便于教学和 Debug。
- 同时兼容 RAM 与“外设寄存器（LCD）”两类目标，后续可扩展到更多外设（增加解码 + state 控制即可）。
- 通过 `bus_ready` 做了最基本的握手机制，避免了组合直接读导致的时序与一致性问题。

### 风险与注意点
1. **LCD 地址解码是精确匹配**  
   `req_addr == 0x7f000000`，没有页/段式映射，地址范围内其他值都当 RAM。
2. **bus_ready 延迟 1~2 个周期**  
   CPU 在 `IDLE` 发起请求时立刻 stall，实际完成在 `DONE` 返回，存在明显吞吐瓶颈；这也是单周期 CPU 常见做法。
3. **未实现读阻塞/错误状态回填**  
   总线无超时、错误码、地址越界、忙状态等保护。
4. **未用到的冗余文件**  
   [peripheral_bus.v](C:/Users/hk/Desktop/summer practice/single_cycle_CPU/single_cycle_CPU.srcs/sources_1/new/peripheral_bus.v) 为空文件，当前总线完全由 `bus_controller` 执行。
5. **指令与数据复用存储空间但物理口分离**  
   数据/指令走不同模块（ROM 与 RAM），不是真正 von Neumann 统一总线；文档里称之为“统一访问通道”更准确的含义是 CPU 的数据请求通路统一。

## 6. 总结

该设计是一个“**单请求、单周期停顿、字地址化的数据总线**”实现：
- CPU 产生请求（仅在访存指令时）；
- 总线控制器在内部寄存后完成 `ACCESS`；
- 通过 `DONE` 周期回传 `ready`；
- 指令读取与数据总线分离，降低了取指与访存冲突，代价是总线吞吐较低、扩展性由地址解码简单度决定。

如果后续需要，我可以再补一版：
- “信号级时序表”（每个周期关键信号波形）；
- 改为“非阻塞式单周期流水（并行下一指令）”或“Pipelined memory bus（握手/READY/VALID）”的升级版总线草图；
- 增加 `wait`/`err`/`byte-enable` 的标准化接口提案。
