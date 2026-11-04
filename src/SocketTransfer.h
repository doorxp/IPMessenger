#ifndef SocketTransfer_h
#define SocketTransfer_h

#include <errno.h>
#include <stddef.h>
#include <sys/select.h>
#include <sys/socket.h>

typedef enum {
	IPMsgSocketSuccess,
	IPMsgSocketStopped,
	IPMsgSocketTimeout,
	IPMsgSocketError,
	IPMsgSocketDisconnected
} IPMsgSocketResult;

static inline int IPMsgSendAll(int socket, const void *bytes, size_t length) {
	const char *cursor = bytes;
	size_t sent = 0;

	while (sent < length) {
		ssize_t count = send(socket, cursor + sent, length - sent, 0);
		if (count > 0) {
			sent += (size_t)count;
			continue;
		}
		if (count < 0 && errno == EINTR) {
			continue;
		}
		return 0;
	}

	return 1;
}

static inline IPMsgSocketResult IPMsgReceiveAll(int socket, void *bytes, size_t length,
	                                             const volatile unsigned char *stop) {
	char *cursor = bytes;
	size_t received = 0;
	int timeoutCount = 0;

	while (received < length && timeoutCount < 40) {
		if (stop && *stop) {
			return IPMsgSocketStopped;
		}

		fd_set readSet;
		FD_ZERO(&readSet);
		FD_SET(socket, &readSet);
		struct timeval timeout = { .tv_sec = 0, .tv_usec = 500000 };
		int selected = select(socket + 1, &readSet, NULL, NULL, &timeout);
		if (selected == 0) {
			timeoutCount++;
			continue;
		}
		if (selected < 0) {
			if (errno == EINTR) {
				continue;
			}
			return IPMsgSocketError;
		}

		ssize_t count = recv(socket, cursor + received, length - received, 0);
		if (count == 0) {
			return IPMsgSocketDisconnected;
		}
		if (count < 0) {
			if (errno == EINTR) {
				continue;
			}
			return IPMsgSocketDisconnected;
		}
		received += (size_t)count;
		timeoutCount = 0;
	}

	return received == length ? IPMsgSocketSuccess : IPMsgSocketTimeout;
}

#endif
