#ifndef __SPECTCMD_H__
#define __SPECTCMD_H__

#define SPECTCMD_CMD_GETRESOURCE (0x00)
#define SPECTCMD_CMD_SETAP (0x01)
#define SPECTCMD_CMD_STARTSCAN (0x02)
#define SPECTCMD_CMD_SAVESNA (0x05)
#define SPECTCMD_CMD_LOADSNA (0x06)
#define SPECTCMD_CMD_SETFILEFILTER (0x07)
#define SPECTCMD_CMD_PLAYTAPE   (0x08)
#define SPECTCMD_CMD_RECORDTAPE (0x09)
#define SPECTCMD_CMD_STOPTAPE   (0x0A)
#define SPECTCMD_CMD_ENTERDIR   (0x0B)

void spectcmd__request(void);
void spectcmd__init(void);

#endif
