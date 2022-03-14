# mbn_utils
Utilities for Qualcomm mbn file are provided.
A mbn file is mainly used to regulate comminucation methods and frequency bands in a cell phone running on a Qualcomm modem.
If the file is changed and flashed into your phone by android `fastboot` command, you can control its behaviour at your own risk.
This mbn_utils is intended to help modification of the file.
It is noted that the method to install the modified mbn file into an unlocked device (**without root**) is an alternative to get **root**, open **diag** port and modify NV items by using **QPST**.
In addition, this tool is inspired by [EfsTools](https://github.com/JohnBel/EfsTools).

## How to use
1. Download this repository and install Ruby
1. Parse a mbn file to be modified with [repack.rb](repack.rb); for instance, the target file named _mcfg_sw.mbn_ is parsed with the following command:
    ```
    ./repack mcfg_sw.mbn
    ```
1. The content of the parsed file is extracted in a directory like _mcfg_sw.mbn.extracted_.
1. Edit the content. The most important file is _mcfg_sw.mbn.extracted/items.txt_, whose each line corresponds to each item of the content with its properties are described in fields separated by commas.
The leading field in a line indicates the item type; 1, 2, and 4 are NV, NV_FILE and FILE, respectively.
The other fields are summarized in the following table.
You can not only modify the parsed items but also add or delete the items.
If you add or delte files in the extracted directory, _items.txt_ should be updated manually.
Especailly, do not forget to update the length located at the 6th filed of NV_FILE or FILE after a file item is modified.
    | 1st field | type | 2nd | 3rd | 4th | 5th | 6th | 7th |
    ----|----|----|----|----|----|----|----
    | 1 | NV | index | magic | hex byte data separated by spaces | | | |
    | 2 or 4 | NV_FILE or FILE | file_name stored in the extratced directory | magic1 | magic2 | magic3 | length in file | offset in file |
1. (Optional) to understand the NV items in _items.txt_, you can use [nv_print.rb](nv_print.rb) to generate human freindly item list:
    ```
    ./nv_print.rb mcfg_sw.mbn.extracted/items.txt
    ```
1. After _items.txt_ and files are modified, rerun `repack.rb` to get the modified mbn file named as _mcfg_sw.mbn.repacked_.
    ```
    ./repack mcfg_sw.mbn
    ```

## Where to get a mbn file
The mbn file is included in a ROM image; for example, `image/modem_pr/mcfg/configs/mcfg_sw/generic/(area)/(operator)/Commercial/mcfg_sw.mbn` in EFS image named `NON-HLOS.bin` of a Xiaomi phone fastboot ROM.
The content of EFS image is extracted with a LINUX machine by usiang a command like `mount -o loop NON-HLOS.bin some_dir`.
