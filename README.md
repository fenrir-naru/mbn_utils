# mbn_utils
Utilities for Qualcomm mbn file are provided.
A mbn file is mainly used to regulate comminucation methods and frequency bands in a cell phone running on a Qualcomm modem.
The goal of this tool is to control behaviour of phone's modem by changing the mbn file and flashing into your phone by android `fastboot` command at your own risk.
It is noted that the method to install the modified mbn file into an unlocked device (**without root**) will be an alternative to get **root**, open **diag** port and modify NV items by using **QPST**.
In addition, this tool is inspired by [EfsTools](https://github.com/JohnBel/EfsTools).

## This tool is under development!
Currently, to change the behaviour by using this tool fails due to mismatch of the digest, which may be related to [Qualcomm secure boot](https://github.com/TalAloni/QualcommSecureBoot-SecondaryExecutableVerifier/).
The digest is included in the last item of the main segment, which corresponds to 32 bytes data ranging from index 79 (counts satrting from zero) in the last line of _items.txt_ described below.
When a successful match is acheieved in the near future, we can check the digest as _/nv/item_files/mcfg/mcfg_sw_config_digest_version_ in modem EFS by using tools such as QPST.
In addition, other digests may be important to make this tool available according to [link](https://www.jianshu.com/p/ca84184877a1), and the below table is the summary.

| file localtion under _image/modem_pr/mcfg/configs_ of NON-HLOS.bin | EFS location |
----|----
| mcfg_sw/generic/(area)/(operator)/Commercial/mcfg_sw.mbn | /nv/item_files/mcfg/mcfg_sw_config_digest_version |
| mcfg_sw/mbn_sw.dig | /nv/item_files/mcfg/mcfg_rfs_sw_digest_version |
| mcfg_hw/mbn_hw.dig | /nv/item_files/mcfg/mcfg_rfs_hw_digest_version |


## How to use
1. Download this repository and install Ruby
1. Parse a mbn file to be modified with [repack.rb](repack.rb); for instance, the target file named _mcfg_sw.mbn_ is parsed with the following command:
    ```
    ./repack mcfg_sw.mbn
    ```
1. The content of the parsed file is extracted in a directory like _mcfg_sw.mbn.extracted_.
1. Edit the content. The most important file is _mcfg_sw.mbn.extracted/items.txt_, whose each line corresponds to each item of the content with its properties are described in fields separated by commas.
The leading field in a line indicates the item type; 1, 2, 4, and 10 are NV, NV_FILE, FILE, and trailer, respectively.
The other fields are summarized in the following table.
You can not only modify the parsed items but also add or delete the items.
If you add or delte files in the extracted directory, _items.txt_ should be updated manually.
Especially, do not forget to update the length located at the 7th filed of NV_FILE or FILE after a file item is modified.
    | 1st field | type | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th |
    ----|----|----|----|----|----|----|----|----
    | 1 | NV | attribute | index | magic | hex byte data separated by spaces | | | |
    | 2 or 4 | NV_FILE or FILE | attribute | file_name stored in the extratced directory | magic1 | magic2 | magic3 | length in file | offset in file |
    | 10 | trailer | attribute | (N.A.) | magic | length | hex byte data separated by spaces | | |
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
