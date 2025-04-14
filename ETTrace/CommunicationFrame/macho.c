//
//  macho.c
//  ETTrace
//
//  Created by Noah Martin on 2/26/25.
//

#include <stdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <unistd.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach-o/swap.h>
#include <string.h>

struct mach_header_64* read_macho(void *map) {  
  struct mach_header_64 *header = (struct mach_header_64 *)map;
  if (header->magic == FAT_MAGIC || header->magic == FAT_CIGAM) {
    struct fat_header fatHeader = *(struct fat_header *) header;
    swap_fat_header(&fatHeader, NX_UnknownByteOrder);
    int numFatArch = fatHeader.nfat_arch;
    header = (struct mach_header_64 *) (((struct fat_header *) header) + 1);
    for (int i = 0; i < numFatArch; i++) {
      struct fat_arch *fatArch = (struct fat_arch *) header;
      struct fat_arch fatArchSwapped = *fatArch;
      swap_fat_arch(&fatArchSwapped, 1, NX_UnknownByteOrder);
      if (fatArchSwapped.cputype == CPU_TYPE_ARM64) {
        header = (struct mach_header_64 *) (map + fatArchSwapped.offset);
        return header;
      } else {
        header = (struct mach_header_64 *) ((char *) header + sizeof(struct fat_arch));
      }
    }
  } else {
    return header;
  }
  
  return -1;
}

long find_symbol_offset(const char *dylib_path, const char *symbol_name) {
  int fd = open(dylib_path, O_RDONLY);
  if (fd < 0) {
      perror("open");
      return -1;
  }
  
  struct stat st;
  if (fstat(fd, &st) < 0) {
      perror("fstat");
      close(fd);
      return -1;
  }
  
  void *map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
  if (map == MAP_FAILED) {
      perror("mmap");
      close(fd);
      return -1;
  }

    struct mach_header_64 *header = read_macho(map);
  if (header <= 0) {
    return -1;
  }
  
  
    struct load_command *lc = (struct load_command *)(header + 1);
  struct symtab_command *symtab = NULL;

    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (lc->cmd == LC_SYMTAB) {
          symtab = (struct symtab_command *)lc;
            break;
        }
        lc = (struct load_command *)((char *)lc + lc->cmdsize);
    }
    
  if (!symtab) {
      fprintf(stderr, "Symbol table not found\n");
      munmap(map, st.st_size);
      close(fd);
      return -1;
  }
    
  struct nlist_64 *symtab_entries = (struct nlist_64 *)((char *)header + symtab->symoff);
  char *strtab = (char *)header + symtab->stroff;
  
  for (uint32_t i = 0; i < symtab->nsyms; i++) {
      if (strcmp(strtab + symtab_entries[i].n_un.n_strx, symbol_name) == 0) {
          long offset = symtab_entries[i].n_value;
          munmap(map, st.st_size);
          close(fd);
          return offset;
      }
  }
  
  fprintf(stderr, "Symbol not found\n");
  munmap(map, st.st_size);
  close(fd);
  return -1;
}
