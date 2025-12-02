# FastULID - 高性能 ULID 实现

[English](README.md)

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://github.com/yaslab/ULID.swift)
[![CocoaPods](https://img.shields.io/cocoapods/v/FastULID.svg)](https://cocoapods.org/pods/FastULID)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Universally Unique Lexicographically Sortable Identifier (ULID) 的高性能 Swift 实现。

API设计灵感来源于 [yaslab/ULID.swift](https://github.com/yaslab/ULID.swift)，设计成同 Foundation UUID 的API，降低使用者的认知负担。在此基础上进行深度性能优化并解决了时钟回拨问题。

## ✨ 特性

### 🚀 性能优化

- **快约 3 倍** ULID 生成（相比 yaslab/ULID.swift）
- **快约 8 倍** 字符串编码（相比 yaslab/ULID.swift）
- **快约 7.8 倍** 字符串解码（相比 yaslab/ULID.swift）
- **快约 5.6 倍** ULID 生成（相比 UUID）
- **快约 28 倍** 批量生成（相比单独生成）
- **100% 互操作** 与 yaslab/ULID.swift 完全兼容
- **零拷贝设计**：最小化内存分配

### 🎯 核心优化技术

1. **内存布局优化**
   - 使用两个 `UInt64` 存储（而非 16 字节元组）
   - 利用64位处理器优势
   - 减少内存访问和缓存缺失

2. **Base32 编解码优化**
   - 静态查找表，编译期优化
   - 循环展开，减少分支
   - 针对ULID的26字符长度特化

3. **比较操作优化**
   - 只需2次 `UInt64` 比较（原实现需16次字节比较）
   - 利用CPU分支预测
   - 时间戳比较作为快速路径

4. **随机数生成优化**
   - 使用 `arc4random_buf` C函数
   - 一次性生成所需随机数
   - 批量生成时优化系统调用

### 🕐 时钟回拨处理

支持两种策略处理时钟回拨问题：

#### 1. 单调模式（Monotonic Mode，默认）
- 检测时钟回拨时使用上次时间戳
- 随机数部分递增保证唯一性
- 始终能生成有效ULID
- 适合大部分场景

#### 2. 严格模式（Strict Mode）
- 检测到时钟回拨时抛出错误
- 允许应用层决定处理方式
- 适合对时间精度要求高的场景

### ⏰ 可配置时间源

支持多种时间提供者：

- **系统时钟**（默认）：使用系统时间
- **单调时钟**：保证时间只会前进
- **混合时间提供者**：结合外部时间源（如NTP）与单调时钟
- **自定义时钟**：实现 `TimeProvider` 协议

#### 使用混合时间提供者

适合需要准确性和可靠性的分布式系统：

```swift
// 步骤 1: 实现你的 NTP 提供者（管理自己的同步逻辑）
class MyNTPProvider: TimeProvider {
    func currentMilliseconds() -> UInt64 {
        // 你的 NTP 实现
        return ntpTimestamp
    }
}

// 步骤 2: 创建混合提供者
let ntpProvider = MyNTPProvider()
let hybridProvider = HybridTimeProvider(referenceProvider: ntpProvider)
let generator = ULIDGenerator(timeProvider: hybridProvider)
```

**为什么使用混合模式？**
- ✅ 来自外部源的准确时间（NTP）
- ✅ 保证时间不后退（单调时钟）
- ✅ 外部提供者控制自己的同步间隔
- ✅ 不干预外部同步逻辑

## 📦 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/elijahdou/FastULID.git", from: "1.0.0")
]
```

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'FastULID', '~> 1.0.0'
```

然后运行：

```bash
pod install
```

## 🚀 快速开始

### 基本使用

```swift
import FastULID

// 生成ULID（使用当前时间）
let ulid = ULID()

// 获取ULID字符串
let string = ulid.ulidString
print(string) // 例如：01ARZ3NDEKTSV4RRFFQ69G5FAV

// 获取ULID二进制数据
let data = ulid.ulidData

// 获取时间戳
let timestamp = ulid.timestamp
print(timestamp) // Date对象
```

### 从字符串/数据创建

```swift
// 从字符串创建
if let ulid = ULID(ulidString: "01ARZ3NDEKTSV4RRFFQ69G5FAV") {
    print("有效的ULID")
}

// 从二进制数据创建
if let ulid = ULID(ulidData: data) {
    print("从数据创建成功")
}

// 使用指定时间戳
let pastDate = Date(timeIntervalSince1970: 1234567890)
let ulid = ULID(timestamp: pastDate)
```

### 使用生成器（推荐）

```swift
import FastULID

// 创建生成器（线程安全）
let generator = ULIDGenerator()

// 生成ULID
let ulid = try generator.generate()

// 批量生成（性能优化）
let ulids = try generator.generateBatch(count: 1000)
```

### 配置时间提供者

```swift
// 使用单调时钟（防止时钟回拨）
let generator = ULIDGenerator(
    timeProvider: MonotonicTimeProvider(),
    strategy: .monotonic
)

// 使用固定时间（测试用）
let generator = ULIDGenerator(
    timeProvider: FixedTimeProvider(timestamp: 1234567890000)
)

// 全局配置（推荐在 AppDelegate 中调用）
ULID.configure(
    timeProvider: MonotonicTimeProvider(),
    strategy: .monotonic
)

// ULID() 现在会使用全局配置
// 它将使用配置的 MonotonicTimeProvider
let ulid = ULID()

// 注意：如果配置了严格模式（strict mode）且发生时钟回拨，
// ULID() 会自动回退到使用系统时间，以确保始终返回有效的 ID。
// 如果你需要捕获严格模式的错误，请直接使用 ULIDGenerator。
```

### 时钟回拨处理

```swift
// 单调模式（默认）- 自动处理时钟回拨
let generator = ULIDGenerator(strategy: .monotonic)
let ulid = try generator.generate() // 始终成功

// 严格模式 - 检测到时钟回拨时抛出错误
let strictGenerator = ULIDGenerator(strategy: .strict)
do {
    let ulid = try strictGenerator.generate()
} catch ULIDGeneratorError.clockBackward(let current, let last, let backward) {
    print("时钟回拨检测：当前=\(current)ms，上次=\(last)ms，回拨=\(backward)ms")
    // 处理错误...
}
```

### JSON序列化

```swift
import FastULID

// ULID支持Codable
struct User: Codable {
    let id: ULID
    let name: String
}

let user = User(id: ULID(), name: "Alice")

// 编码
let encoder = JSONEncoder()
let jsonData = try encoder.encode(user)

// 解码
let decoder = JSONDecoder()
let decodedUser = try decoder.decode(User.self, from: jsonData)
```

### UUID互转

```swift
// ULID转UUID
let ulid = ULID()
let uuid = UUID(uuid: ulid.ulid)
print(uuid.uuidString) // 01684626-765B-F5CE-0486-7FB7F05E443D

// UUID转ULID
let uuid = UUID()
let ulid = ULID(ulid: uuid.uuid)
print(ulid.ulidString) // 26字符Base32编码
```

### 排序和比较

```swift
var ulids = [ULID]()
for _ in 0..<100 {
    ulids.append(ULID())
}

// ULID的字典序等同于时间序
let sorted = ulids.sorted()

// 比较操作
if ulid1 < ulid2 {
    print("ulid1 生成时间早于 ulid2")
}
```

### 并发生成

```swift
import FastULID

// ULIDGenerator 是线程安全的
let generator = ULIDGenerator()

// 从多个线程生成ULID
DispatchQueue.concurrentPerform(iterations: 10) { index in
    do {
        let ulid = try generator.generate()
        print("线程 \(index): \(ulid.ulidString)")
    } catch {
        print("生成失败: \(error)")
    }
}

// 批量生成对于高并发场景更高效
let ulids = try generator.generateBatch(count: 10000)
print("批量生成了 \(ulids.count) 个 ULID")
```

## 📊 性能基准

**测试平台:** Apple Silicon (arm64), 14 核心, 24GB RAM  
**Xcode 版本:** 26.1.1  
**Swift 版本:** 5.9+  
**编译模式:** Release (-O)  
**测试迭代:** 100,000 次

运行基准测试：

```bash
# CPU 性能测试
swift run -c release FastULIDBenchmark

# 完整对比测试（性能 + 内存）
cd Benchmarks && ./run_all_comparisons.sh

# 或单独运行：
# 内存对比测试（vs yaslab）
cd Benchmarks/MemoryComparison && ./run_memory_comparison.sh

# 性能对比测试（vs yaslab）
cd Benchmarks/YaslabComparison && swift run -c release
```

### 核心性能（实际测试结果）

| 操作 | 平均耗时 | 吞吐量 |
|------|---------|--------|
| ULID 生成 | ~26 ns | ~3800万次/秒 |
| 字符串编码 | ~29 ns | ~3400万次/秒 |
| 字符串解码 | ~27 ns | ~3700万次/秒 |
| 相等比较 (==) | ~0 ns | ∞ |
| 哈希计算 | ~12 ns | ~8000万次/秒 |
| 批量生成（每ID）| ~1.7 ns | ~5.9亿次/秒 |
| 并发生成（8线程）| ~450 ns | ~220万次/秒 |
| JSON 编码 | ~430 ns | ~230万次/秒 |
| JSON 解码 | ~430 ns | ~230万次/秒 |

### FastULID vs UUID

| 操作 | ULID (ns) | UUID (ns) | ULID 优势 |
|------|-----------|-----------|-----------|
| **ID生成** | **~27** | **~151** | **快约 5.6 倍** |
| **字符串编码** | **~33** | **~44** | **快约 1.3 倍** |
| **字符串解码** | **~25** | **~129** | **快约 5.2 倍** |
| **相等比较** | ~0 | ~0.9 | 快 ∞ 倍 |
| **哈希计算** | ~12 | ~12 | ~1.0x（持平）|
| **JSON 编码** | **~430** | **~480** | **快约 1.1 倍** |
| **JSON 解码** | **~430** | **~530** | **快约 1.2 倍** |
| **批量生成** | **~1.7** | N/A | **快约 28 倍** |

**说明：**
- ✅ **生成快约 5.6 倍** - 核心优势
- ✅ **字符串解码快约 5.2 倍** - 极致优化的零内存分配实现
- ✅ **字符串编码快约 1.3 倍** - 超越了系统原生 UUID 的编码速度
- ✅ **JSON 性能** - 序列化和反序列化均优于 UUID
- ✅ **批量模式快约 28 倍**

### FastULID vs yaslab/ULID.swift

| 操作 | FastULID (ns) | yaslab (ns) | FastULID 优势 |
|------|-------------|-------------|------------|
| **ID生成** | **~25** | **~76** | **快约 3 倍** |
| **字符串编码** | **~29** | **~238** | **快约 8.2 倍** |
| **字符串解码** | **~28** | **~217** | **快约 7.8 倍** |
| **时间戳提取** | **~1.4** | **~1.9** | **快约 1.4 倍** |
| **Data 编码** | ~49 | ~48 | ~0.98x（持平）|
| **批量生成** | **~1.7** | N/A | **快约 28 倍** |

**说明：**
- ⚡️ **字符串编码快约 8 倍** - 直接位运算优化
- ⚡️ **字符串解码快约 7.8 倍** - 零内存分配实现
- ✅ **ID生成快约 3 倍** - 节省约 66% CPU
- ✅ **批量模式快约 28 倍** - yaslab 无此功能
- ✅ **100% 互操作** - 已验证 String、Data、Timestamp 输出完全一致


运行 yaslab 对比测试：
```bash
cd Benchmarks/YaslabComparison
swift run -c release YaslabComparison
```

### 内存使用对比（FastULID vs yaslab/ULID.swift）

| 测试场景 | FastULID | yaslab | FastULID 优势 |
|---------|----------|---------|--------------|
| **结构体大小** | 16 字节 | 16 字节 | 相同 |
| **结构体对齐** | 8 字节 | 1 字节 | 更优的缓存对齐 |
| **生成 1万个** | 160 KB | 224 KB | **节省 28.6%** |
| **生成 10万个** | 1.56 MB | 1.53 MB | 相当 |
| **解码 10万次** | 0 MB | 1.56 MB | **节省 100%** |

**内存优势：**
- ✅ **小规模生成节省内存** - 1万个 ID 节省 28.6% 内存
- ✅ **零内存解码** - 字符串解码过程无额外内存分配
- ✅ **更好的缓存对齐** - 8 字节对齐优化 CPU 缓存效率
- ✅ **批量模式内存稳定** - 批量生成内存使用可预测

运行内存对比测试：
```bash
cd Benchmarks/MemoryComparison
swift run -c release MemoryComparison
# 或使用脚本
./run_memory_comparison.sh
```

## 🏗️ 架构设计

### 模块结构

```
Sources/FastULID/
├── ULID.swift              # 核心ULID结构体
├── Base32Codec.swift       # 高性能Base32编解码器
├── ULIDGenerator.swift     # 线程安全的ULID生成器
└── TimeProvider.swift      # 时间提供者协议及实现
```

### 内存布局

```
ULID结构体（16字节）：
┌─────────────────────┬─────────────────────┐
│   high: UInt64      │    low: UInt64      │
├─────────────────────┴─────────────────────┤
│  时间戳(48位) | 随机数(16位) | 随机数(64位)   │
└───────────────────────────────────────────┘
```

### 关键优化点

1. **编译器提示**
   - `@inline(__always)`：强制内联关键函数
   - `@usableFromInline`：允许跨模块内联
   - `@frozen`：固定结构体布局

2. **分支预测**
   - 快速路径优化（时间戳不同的情况）
   - 减少条件分支

3. **缓存友好**
   - 紧凑的内存布局
   - 查找表对齐
   - 减少指针跳转

## 🧪 测试

运行单元测试：

```bash
swift test
```

测试覆盖率 > 95%，包括：

- ✅ 基本功能测试
- ✅ 编解码测试
- ✅ 排序和比较测试
- ✅ 时钟回拨处理测试
- ✅ 并发安全测试
- ✅ 边界条件测试
- ✅ 性能测试

## 📖 ULID规范

ULID（Universally Unique Lexicographically Sortable Identifier）是一个128位标识符，具有以下特性：

- **128位**：与UUID相同大小
- **字典序可排序**：基于时间戳排序
- **大小写不敏感**：Base32编码
- **无特殊字符**：URL友好
- **单调递增**：同一毫秒内保证递增

### 结构

```
 01AN4Z07BY      79KA1307SR9X4MV3
|----------|    |----------------|
 时间戳（10字符）  随机数（16字符）
 48位            80位
```

### 编码

- 使用 Crockford's Base32 编码
- 字符集：`0123456789ABCDEFGHJKMNPQRSTVWXYZ`
- 排除容易混淆的字母：I、L、O、U
- 大小写不敏感：i/I→1, l/L→1, o/O→0

更多信息请参考：[ULID规范](https://github.com/ulid/spec)

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- API灵感：[yaslab/ULID.swift](https://github.com/yaslab/ULID.swift)
- ULID规范：[ulid/spec](https://github.com/ulid/spec)
- 参考实现：
  - [Cysharp/Ulid](https://github.com/Cysharp/Ulid) (C#)
  - [ulid-rs](https://github.com/dylanhart/ulid-rs) (Rust)

## 🔗 相关资源

- [ULID规范](https://github.com/ulid/spec)
- [UUID vs ULID](https://sudhir.io/uuids-ulids)

---



