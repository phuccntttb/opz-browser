#!/usr/bin/env python3
"""Put Opz's icon into the 7-Zip SFX stub of the Windows installer.

    win-sfx-icon.py <7zSD.Win32.sfx> <icon.ico> <out.sfx>

The installer .exe is that stub + a tag + a 7z archive (mach repackage
installer). Mozilla's stub carries the Firefox logo, which Explorer shows as
the installer's icon. Each icon image in the stub's resources is overwritten in
place by the image of the same size and bit depth from <icon.ico>, which must
not be larger (Opz's are small PNGs), so no part of the file moves.
"""
import struct
import sys

RT_ICON, RT_GROUP_ICON = 3, 14


def ico_images(path):
    d = open(path, "rb").read()
    _, typ, n = struct.unpack_from("<HHH", d, 0)
    if typ != 1:
        sys.exit(f"win-sfx-icon: {path} is not an .ico")
    out = {}
    for i in range(n):
        w, h, _, _, _, bpp, size, off = struct.unpack_from("<BBBBHHII", d, 6 + 16 * i)
        out[(w or 256, h or 256, bpp)] = d[off : off + size]
    return out


def main(sfx_in, ico, sfx_out):
    pe = bytearray(open(sfx_in, "rb").read())
    new = ico_images(ico)

    lfanew = struct.unpack_from("<I", pe, 0x3C)[0]
    if pe[lfanew : lfanew + 4] != b"PE\0\0":
        sys.exit("win-sfx-icon: not a PE file")
    nsect, = struct.unpack_from("<H", pe, lfanew + 6)
    optsize, = struct.unpack_from("<H", pe, lfanew + 20)
    opt = lfanew + 24
    magic, = struct.unpack_from("<H", pe, opt)
    ddir = opt + (96 if magic == 0x10B else 112)
    rsrc_rva, _ = struct.unpack_from("<II", pe, ddir + 2 * 8)
    sections = []
    for i in range(nsect):
        s = opt + optsize + 40 * i
        vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", pe, s + 8)
        sections.append((va, max(vsize, rawsize), rawptr))

    def off(rva):
        for va, size, raw in sections:
            if va <= rva < va + size:
                return raw + rva - va
        sys.exit(f"win-sfx-icon: RVA {rva:#x} is in no section")

    base = off(rsrc_rva)

    def entries(dir_off):
        named, ids = struct.unpack_from("<HH", pe, base + dir_off + 12)
        for i in range(named + ids):
            name, data = struct.unpack_from("<II", pe, base + dir_off + 16 + 8 * i)
            yield name, data

    def leaves(type_id):
        """(resource id, file offset of its IMAGE_RESOURCE_DATA_ENTRY)"""
        for t, tdata in entries(0):
            if t != type_id or not tdata & 0x80000000:
                continue
            for rid, rdata in entries(tdata & 0x7FFFFFFF):
                for _, ldata in entries(rdata & 0x7FFFFFFF):
                    yield rid, base + ldata

    icons = {rid: entry for rid, entry in leaves(RT_ICON)}
    replaced = 0
    for _, gentry in leaves(RT_GROUP_ICON):
        grva, _ = struct.unpack_from("<II", pe, gentry)
        g = off(grva)
        count, = struct.unpack_from("<H", pe, g + 4)
        for i in range(count):
            e = g + 6 + 14 * i
            w, h, _, _, _, bpp, size, nid = struct.unpack_from("<BBBBHHIH", pe, e)
            key = (w or 256, h or 256, bpp)
            img = new.get(key)
            if img is None:
                sys.exit(f"win-sfx-icon: {ico} has no {key[0]}x{key[1]} {bpp}-bit image")
            dentry = icons[nid]
            drva, dsize = struct.unpack_from("<II", pe, dentry)
            if len(img) > dsize:
                sys.exit(f"win-sfx-icon: {key[0]}x{key[1]} image is {len(img)} bytes, room for {dsize}")
            d = off(drva)
            pe[d : d + dsize] = img + bytes(dsize - len(img))
            struct.pack_into("<I", pe, dentry + 4, len(img))
            struct.pack_into("<I", pe, e + 8, len(img))
            replaced += 1
    if not replaced:
        sys.exit("win-sfx-icon: no icon found in the stub")
    open(sfx_out, "wb").write(pe)
    print(f"win-sfx-icon: replaced {replaced} icon image(s)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
