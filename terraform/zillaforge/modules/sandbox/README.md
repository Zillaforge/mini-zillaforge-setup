# Sandbox (Server) 模組說明

此模組會建立一或多個虛擬主機（server）、為每個主機建立 Floating IP，並將 Floating IP 指派到對應的主機上。

**使用情境**：在測試或開發環境快速建立 sandbox 主機，支援以名稱或 ID 提供 image、flavor、network、keypair、security group 等資源，並可透過 `user_data` 或內建的 pre-install 腳本初始化主機。

**重要行為摘要**:
- 當 `user_data` 非空時，模組會將 `user_data` 的內容直接當作雲端初始化內容（優先於 `pre_install`）。
- 當 `user_data` 為空且 `pre_install` 為非空字串時，模組會嘗試載入 `modules/sandbox/setup_scripts/<pre_install>_setup.sh` 作為初始化腳本。


## Inputs（輸入參數）

以下欄位對應 `modules/sandbox/variables.tf` 中定義（含型別與預設值）：

- `name` (string): Server name. (no default)
- `flavor_id` (string): (Optional) Flavor id to use for the server. Default: `""`.
- `flavor_name` (string): (Optional) Flavor name to lookup when `flavor_id` is not provided. Default: `"Basic.large"`.
- `image_id` (string): (Optional) Image id to use for the server. Default: `""`.
- `image_repository` (string): (Optional) Image repository name to lookup when `image_id` is not provided. Default: `"ubuntu"`.
- `image_tag` (string): (Optional) Image tag to lookup when `image_id` is not provided. Default: `"2404"`.
- `keypair_id` (string): (Optional) Keypair id to use for the server. Default: `""`.
- `keypair_name` (string): (Optional) Keypair name to lookup when `keypair_id` is not provided. Default: `"ogre0403"`.
- `network_id` (string): (Optional) Network id to attach the server to. Default: `""`.
- `network_name` (string): (Optional) Network name to lookup when `network_id` is not provided. Default: `"default"`.
- `security_group_ids` (list(string)): Optional list of security group ids to attach. When empty, module will lookup `sg_name` and use its id. Default: `[]`.
- `sg_id` (string): (Optional) Security group id to use. Default: `""`.
- `sg_name` (string): (Optional) Security group name to lookup when `sg_id` is not provided. Default: `"allow-all"`.
- `user_data` (string): User data for the server. If non-empty, it takes precedence over `pre_install`. Default: `""`.
- `pre_install` (string): Select a pre-install script by name (e.g., "devstack" or "zillaforge"). Empty string means no pre-install script. If non-empty, the module will use the file at `setup_scripts/<name>_setup.sh`. Default: `""`.
-  - Validation: `pre_install` must be empty or match an existing script under `modules/sandbox/setup_scripts` (the module validates this at plan time).
-
注意：本 module 並未定義 top-level 變數 `name` 或 `total`；若需要建立多個實例，請在外層呼叫模組時使用 Terraform 的 `count` 或 `for_each`，並由呼叫端決定每個實例的 `name`。（在本 repository 的 root module 中，變數 `total` 用來控制實例數量）
- `floating_ip_name` (string): Name for the floating IP. Default: `""`.
- `reserved_fip` (string): (Optional) IP address of an already-reserved floating IP to use for this sandbox. When provided and found, the module will use the existing floating IP; if not provided or not found, the module will create a new floating IP. Default: `""`.


## Outputs（輸出）

以下輸出對應 `modules/sandbox/outputs.tf` 中定義：

- `server_id` : value = `zillaforge_server.this.id`
- `server_name` : value = `zillaforge_server.this.name`
- `floating_ip_id` : value = `local.floating_ip_id` (may reference an existing reserved FIP when `reserved_fip` is used)
- `floating_ip_address` : value = `local.floating_ip_address` (may reference an existing reserved FIP when `reserved_fip` is used)

注意：上述輸出為模組中宣告的名稱與其對應值；如果你在外層使用 `count`/`for_each` 包裝模組，Terraform 在 root module 層會回傳陣列或映射，行為視外層呼叫方式而定。

## 使用範例

1) 使用模組預設的 `pre_install`（內建 `zillaforge`）：

```hcl
module "sandbox" {
  source      = "../modules/sandbox"
  name        = "sandbox-by-terraform"
  pre_install = "zillaforge"
}
```

2) 使用 `user_data` 直接注入 cloud-init（覆蓋 `pre_install`）：

```hcl
module "sandbox" {
  source    = "../modules/sandbox"
  name      = "sandbox-userdata"
  flavor_id = "..."
  image_id  = "..."
  network_id = "..."
  keypair_id = "..."
  user_data = file("./my_cloud_init.yaml")
}
```

3) 使用名稱讓模組自動查找資源 ID（當你只有名稱時）：

```hcl
module "sandbox" {
  source           = "../modules/sandbox"
  name             = "sandbox-by-name"
  flavor_name      = "Basic.large"
  image_repository = "ubuntu"
  image_tag        = "2404"
  keypair_name     = "ogre0403"
  network_name     = "default"
  sg_name          = "allow-all"
}
```

4) 在外層呼叫建立多台 sandbox（使用 `count` 或 `for_each`）：

使用 `count` 並在 `name` 中使用 `count.index` 來產生零補齊編號：

```hcl
module "sandbox" {
  source = "../modules/sandbox"
  count  = 3

  name           = format("sandbox-by-terraform-%02d", count.index + 1)
  flavor_name    = "Basic.large"
  image_repository = "ubuntu"
  image_tag        = "2404"
  keypair_name     = "ogre0403"
  network_name     = "default"
}
```

或使用 `for_each` 與名稱列表：

```hcl
locals {
  sandbox_names = ["sandbox-01", "sandbox-02", "sandbox-03"]
}

module "sandbox" {
  source   = "../modules/sandbox"
  for_each = toset(local.sandbox_names)

  name = each.value
  # 其他必需參數 (image/flavor/network 等)
}
```

## 自訂 pre-install 腳本
要新增可被 `pre_install` 使用的預設初始化腳本，請在模組路徑下建立一個檔案：

```
modules/sandbox/setup_scripts/<name>_setup.sh
```

然後在模組參數中指定 `pre_install = "<name>"`。若同時提供 `user_data`，則 `user_data` 仍會被優先使用。

## 注意事項與建議
- 若你已有資源的 ID（例如 image、flavor、network、keypair、security group），建議直接提供 ID，可避免名稱查找造成的不確定性。
- 在建立多個 sandbox 時，請注意目標雲端配額（CPU、RAM、Floating IP 數量等）。
- Floating IP 的建立與指派方式會依照 OpenStack 或雲端提供者的行為而有差異；若需要特定網段或子網，請在模組外預先建立並以 `network_id` 指定。

## 範例：輸出使用
建立完成後可透過下列方式取得建立資源：

```hcl
output "sandbox_ips" {
  value = module.sandbox.floating_ip_address
}
```

此輸出在 `total > 1` 時會是陣列。

