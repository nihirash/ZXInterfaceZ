#ifndef __MAINWINDOW_H__
#define __MAINWINDOW_H__


#include <QMainWindow>
#include <QAbstractSocket>
#include <QString>
#include <QByteArray>
#include <QHostAddress>

class QString;
class QHostAddress;
class QUdpSocket;
class QTcpSocket;
class SpectrumRenderArea;
class UDPListener;
class QStatusBar;
class ProgressBar;
class LineBuffer;

class MainWindow: public QMainWindow
{
public:
    MainWindow(const char *host);

    bool sendReceive(const QHostAddress &address, void (MainWindow::*callback)(QByteArray*),
                     bool callImmediatlyOnReception,
                     const QString &data, const QByteArray &bindata=QByteArray(),
                     bool show_progress=false);

    void onGetFBClicked();
    void fbReceived(QByteArray*);
    void progressReceived(QByteArray*);
    void captureReceived(QByteArray*data);

    void uploadROM(const QString &filename);
    void uploadSNA(const QString &filename);
    void uploadOTA(const QString &filename);
    void uploadFPGA(const QString &filename);
    void uploadResource(const QString &filename);

    void sendInChunks(QTcpSocket*sock, QByteArray&data);

    void alert(const QString&);

public slots:
    void commandSocketError(QAbstractSocket::SocketError socketError);
    void commandSocketConnected();
    void commandSocketRead();
    void onStreamClicked();
    void onUploadROMClicked();
    void onUploadSNAClicked();
    void onUploadOTAClicked();
    void onUploadFPGAClicked();
    void onLoadResourceClicked();
    void onResetClicked();
    void onResetToCustomClicked();
    void onFpsUpdated(unsigned);
    void onCaptureClicked();
    void onWideClicked();
    void onExit();
    void onStatusLineReceived(QString);
protected:
    void processStatus(const QString &s);
    void reverseBits(QByteArray &b);

private:
    QUdpSocket *m_udpsocket;
    UDPListener *m_listener;
    SpectrumRenderArea *m_renderer;

    bool m_connecting;
    QTcpSocket *m_cmdSocket;
    QString m_cmd;
    void (MainWindow::*m_cmdHandler)(QByteArray*);
    QByteArray *m_result;
    QByteArray m_bindata;
    bool m_callimmediatly;
    QStatusBar *m_statusbar;
    QHostAddress m_zxaddress;
    ProgressBar *m_progress;
    LineBuffer *m_linebuffer;
};

#endif
