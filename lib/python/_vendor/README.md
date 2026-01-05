# Vendor Libraries

- dotfilesで利用するPyPIライブラリーのコピーを管理します。
- ビルドが必要もしくは純粋なPython3で動作しないライブラリーは使用しません。
- 管理しているベンダーライブラリーは `vendor.txt` で管理します。
- `vendor.txt` を更新した場合、`make install` で更新します。
- 管理されるライブラリーのライセンスは `./licenses` を参照ください。
