# waterflow_CPU 存储与 MMIO 总线

## 1. 总体结构

CPU 使用独立的指令请求和数据请求通道。两级阻塞式缓存、Boot DMA
和 DDR3 MIG 通过 `mem_subsystem.v` 仲裁；MMIO 数据请求进入
`mmio_tdm_bus.v`。所有请求采用 valid/ready 握手，响应采用
valid/ready 握手。

SoC、缓存、MMIO、NAND Boot 和 VGA 工作在 25 MHz；MIG 工作在自己的
UI 时钟域，`ddr_cdc_bridge.v` 负责跨时钟域。Boot 完成前，CPU 保持
复位且 Boot DMA 独占 DDR 和物理 NAND 总线。

## 2. 启动流程

NAND 第 0 页保存 32 字节 Boot v1 头部，payload 从第 1 页开始。
`nand_boot_loader.v` 验证 magic、版本、长度、固定加载/入口地址，
随后单遍读取 NAND、写入 DDR `0x1c000000` 并计算 CRC32。只有最后
一次 DDR 写响应完成且 CRC 正确后，`boot_done` 才释放 CPU。

最大 payload 为 63 个 2048 字节页面，即 129024 字节。任何头部、
NAND、DDR 或 CRC 错误都会保持 CPU 复位，并通过数码管显示
`BAD00001` 到 `BAD00005`。

## 3. MMIO 映射

| 地址 | 外设 | 寄存器 |
|---|---|---|
| `0x1fe00000` | PS/2 | `+0` 状态，`+4` 原始 Set-2 FIFO，`+8` 清错误 |
| `0x1fe10000` | VGA | `4*(y*80+x)` 字符，`+0x3ffc` 清屏/忙状态 |
| `0x1fe20000` | Timer | 25 MHz 自由运行计数器 |
| `0x1fe30000` | UART | 读 bit0=busy，写低 8 位发送，115200 8N1 |
| `0x1fe50000` | 数码管 | `+0/+4` 八个段码，`+8` 位使能，`+0xc` Boot 状态 |
| `0x1fe60000` | LED | 低 16 位逻辑灯值，bit0 对应最左侧，1=亮 |
| `0x1fd00000` | NAND | `+0` 状态/命令，`+4` 数据，`+8` word index |

`mmio_tdm_bus` 每 8 个周期轮询一个 slot：PS/2=0、VGA=1、Timer=2、
UART=3、NAND=4、数码管=5、LED=7。无效地址返回 `resp_err`。

## 4. 外设约定

- VGA 固定为 640x480、80x30 字符、8x16 字体，白字黑底。
- PS/2 硬件只校验并缓存原始 Set-2 字节；Shift、Caps 和 ASCII 映射由
  C SDK 完成。
- 数码管 digit0 为最左位；段码 bit0..7 为 A,B,C,D,E,F,G,DP。
- 普通 LED 在板上低有效，顶层负责反相，软件始终使用 1=亮。
- UART 分频基于实际 25 MHz，标准位宽为 217 个 SoC 周期。

## 5. 错误与复位

MMIO 在 Boot 完成前保持复位，避免 Boot Loader 与 NAND MMIO 控制器
同时驱动物理总线。数码管扫描器位于 MMIO 复位域之外，因此等待 DDR、
读取头部、复制进度和错误码仍可显示。Boot 成功码保留约 250 ms，然后
显示权交给软件寄存器。
