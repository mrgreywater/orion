#ifndef SMOTHIMAGEPROVIDER_H
#define SMOTHIMAGEPROVIDER_H
#include <QQuickImageProvider>
#include <QNetworkAccessManager>
#include <QEventLoop>
#include <QNetworkReply>
#include <QFile>
#include <QUrl>
#include <QProcess>
#include <QDir>
#include <QFileInfo>

class SmoothImageProvider : public QQuickImageProvider
{
public:
    SmoothImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {

    }

    QPixmap requestPixmap(const QString &url, QSize *size, const QSize &requestedSize) override {
        QNetworkAccessManager nam;
        QEventLoop loop;
        QObject::connect(&nam, &QNetworkAccessManager::finished, &loop, &QEventLoop::quit);

        QNetworkReply *reply = nam.get(QNetworkRequest(url));
        loop.exec();

        QFile file(QUrl(url).fileName());

        auto inputPath = QFileInfo(file).absoluteFilePath();
        auto outPath = QFileInfo(QFile(inputPath + ".png")).absoluteFilePath();

        QPixmap pm;

        if (!QFileInfo(outPath).exists()) {
            file.open(QIODevice::WriteOnly);
            file.write(reply->readAll());
            reply->deleteLater();
            file.close();


            //QStringList arguments;
            //arguments << (QString("\"") + inputPath + "\"");
            //arguments << (QString("-o\"") + outPath + "\"");

            QProcess jpeg2png;
            jpeg2png.setWorkingDirectory(QDir::currentPath());
            jpeg2png.start("jpeg2png.exe \"" + inputPath + "\" -o\"" + outPath + "\"");

            if (jpeg2png.waitForFinished() && jpeg2png.exitCode() == 0) {
                pm.load(outPath);
            } else {
                pm.load(inputPath);
            }
        } else {
            pm.load(outPath);
        }

        *size = QSize(pm.width(), pm.height());

        return pm;
    }
};

#endif // SMOTHIMAGEPROVIDER_H
