//
//  ViewController.swift
//  FileTransfer
//
//  Created by 李爱红 on 2019/8/28.
//  Copyright © 2019 elastos. All rights reserved.
//

import UIKit

var transferFrientId = ""
var friendState = ""
var receiveoffset = 0
var receiveData = Data()
var receiveinfo = CarrierFileTransferInfo()
let time = Timestamp.getTimeAtNow()
var sendPath = NSHomeDirectory() + "/Library/Caches/" + "send_\(time)"
var receivePath = NSHomeDirectory() + "/Library/Caches/" + "receive_\(time)"

@available(iOS 11.0, *)
class ViewController: UIViewController {

    var qrcodeView: UIImageView!
    var friendView: CommonView!
    var fileView: CommonView!
    var transfile: CommonView!
    var stackView: UIStackView!
    var showImage: UIImageView!
    var sfileTransfer: CarrierFileTransfer!
    var imgDate: Data!

    override func viewDidLoad() {
        super.viewDidLoad()
        creatUI()
        creatBarItem()
        loadMyInfo()
        NotificationCenter.default.addObserver(self, selector: #selector(handleFriendStatusChanged(notif:)), name: .friendStatusChanged, object: nil)
        do {
            try CarrierFileTransferManager.initializeSharedInstance(carrier: DeviceManager.sharedInstance.carrierInst, connectHandler: handle)
        } catch {
            print(error)
        }
    }

    func creatBarItem() {
       let item = UIBarButtonItem(title: "添加", style: UIBarButtonItem.Style.plain, target: self, action: #selector(addDevice))
        item.tintColor = UIColor.black
        self.navigationItem.rightBarButtonItem = item
    }

    func creatUI() {

        friendView = CommonView()
        friendView.title.text = "Friend"
        friendView.textFile.placeholder = "Please selected friend."
        friendView.row.image = UIImage(named: "row")
        friendView.state.text = "None"
        friendView.state.textColor = UIColor.lightGray
        friendView.button.addTarget(self, action: #selector(showFriends), for: .touchUpInside)
        friendView.subTitle.text = "State"
        
        fileView = CommonView()
        fileView.title.text = "File"
        fileView.subTitle.text = "State"
        fileView.state.text = "Off"
        fileView.state.textColor = UIColor.lightGray
        fileView.row.image = UIImage(named: "row")
        fileView.button.addTarget(self, action: #selector(goPhoto), for: .touchUpInside)
        fileView.textFile.placeholder = "Please selected file."

        transfile = CommonView()
        transfile.title.text = ""
        transfile.button.setTitle("TransferFile", for: .normal)
        transfile.button.backgroundColor = UIColor.lightGray
        transfile.button.isEnabled = false
        transfile.button.addTarget(self, action: #selector(submit), for: .touchUpInside)
        transfile.button.layer.cornerRadius = 5.0
        transfile.button.layer.masksToBounds = true

        stackView = UIStackView(arrangedSubviews: [friendView, fileView, transfile])
        stackView.axis = NSLayoutConstraint.Axis.vertical
        stackView.alignment = UIStackView.Alignment.fill
        stackView.distribution = UIStackView.Distribution.fillEqually
        stackView.spacing = 12
        self.view.addSubview(stackView)

        qrcodeView = UIImageView()
        qrcodeView.backgroundColor = UIColor.red
        self.view.addSubview(qrcodeView)

        showImage = UIImageView()
        showImage.backgroundColor = UIColor.red
        self.view.addSubview(showImage)

        qrcodeView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100)
            make.centerX.equalToSuperview()
            make.height.width.equalTo(120)
        }
        stackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.top.equalTo(qrcodeView.snp_bottom).offset(24)
            make.height.equalTo(100 * 3)
        }

        showImage.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp_bottom).offset(12)
            make.height.width.equalTo(88)
            make.left.equalTo(stackView)
        }

    }

    func checkTransferButton() {
        guard friendView.textFile!.text != nil else {
            transfile.button.backgroundColor = UIColor.lightGray
            transfile.button.isEnabled = false
            return
        }
        guard friendView.state.text == "Online" else {
            transfile.button.backgroundColor = UIColor.lightGray
            transfile.button.isEnabled = false
            return
        }
        guard showImage.image != nil else {
            transfile.button.backgroundColor = UIColor.lightGray
            transfile.button.isEnabled = false
            return
        }
        transfile.button.isEnabled = true
        transfile.button.backgroundColor = ColorHex("#7f51fc")
    }

    func loadMyInfo() {
        if let carrierInst = DeviceManager.sharedInstance.carrierInst {
            if (try? carrierInst.getSelfUserInfo()) != nil {
                let address = carrierInst.getAddress()
                let qrCode = QRCode(address)
                qrcodeView!.image = qrCode?.image
                return
            }
        }
    }

    func refresh(_ status: CarrierConnectionStatus) {
        if status == CarrierConnectionStatus.Connected {
            self.friendView.state.text = "Online"
            self.friendView.state.textColor = UIColor.green
        }else {
            self.friendView.state.textColor = UIColor.lightGray
            self.friendView.state.text = "Offline"
        }
        checkTransferButton()
    }

    //    MARK: action
    @objc func addDevice() {
        let scanVC = ScanViewController();
        self.navigationController?.show(scanVC, sender: nil)
    }

    @objc func showFriends() {
        let listVC = ListViewController()
        listVC.callBack { value in
            transferFrientId = value.userId!
            self.friendView.textFile.text = value.userId!
            self.refresh(value.status)
        }
        self.navigationController?.pushViewController(listVC, animated: true)
    }

    @objc func goPhoto() {
        let photoPicker = UIImagePickerController()
        photoPicker.delegate = self
        photoPicker.allowsEditing = true
        photoPicker.sourceType = .photoLibrary
        self.present(photoPicker, animated: true, completion: nil)
    }

    @objc func submit() {
        print("触发了提交按钮")
        do {
            let friendId = friendView.textFile.text ?? ""
            let fileInfo = CarrierFileTransferInfo()
            let fileId: String = try CarrierFileTransfer.acquireFileId()
            fileInfo.fileId = fileId
            fileInfo.fileName = "test1"
            imgDate = NSData(data: showImage.image!.jpegData(compressionQuality: 1)!) as Data
            let fileManager = FileManager.default
            let exist = fileManager.fileExists(atPath: sendPath)
            if !exist {
                fileManager.createFile(atPath: sendPath, contents: nil, attributes: nil)
                let writeHandle = FileHandle(forWritingAtPath: sendPath)
                writeHandle?.seek(toFileOffset: 0)
                writeHandle?.write(imgDate!)
            }
            fileInfo.fileSize = UInt64(imgDate.count)
            sfileTransfer = try CarrierFileTransferManager.sharedInstance()?.createFileTransfer(to: friendId, withFileInfo: fileInfo, delegate: self)
           try sfileTransfer.sendConnectionRequest()
        } catch {
            print(error)
        }
    }

    func handle(carrier: Carrier, from: String, info: CarrierFileTransferInfo) {
        print(from)
        do {
            receiveinfo = info
            if (sfileTransfer == nil) {
                sfileTransfer = try CarrierFileTransferManager.sharedInstance()?.createFileTransfer(to: from, withFileInfo: info, delegate: self)
            }
            try sfileTransfer!.acceptConnectionRequest()
        } catch {
            print(error)
        }
    }

    //MARK: - NSNotification -
    @objc func handleFriendStatusChanged(notif: NSNotification) {
        let friendState = notif.userInfo!["friendState"] as! CarrierConnectionStatus
        DispatchQueue.main.sync {
            self.refresh(friendState)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate
@available(iOS 11.0, *)
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image : UIImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        fileView.textFile.text = (info[UIImagePickerController.InfoKey.mediaType] as! String)
        showImage.image = image
        checkTransferButton()
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - CarrierFileTransferDelegate
@available(iOS 11.0, *)
extension ViewController: CarrierFileTransferDelegate {

    func fileTransferStateDidChange(_ fileTransfer: CarrierFileTransfer, _ newState: CarrierFileTransferConnectionState) {
        print("fileTransferStateDidChange ====== \(fileTransfer)")

    }

    func didReceiveFileRequest(_ fileTransfer: CarrierFileTransfer, _ fileId: String, _ fileName: String, _ fileSize: UInt64) {
        print("didReceiveFileRequest ====== \(fileTransfer)")
        do {
            try sfileTransfer.sendPullRequest(fileId: fileId, withOffset: 0)
        } catch {
            print(error)
        }
    }

    func didReceivePullRequest(_ fileTransfer: CarrierFileTransfer, _ fileId: String, _ offset: UInt64) {
        print("didReceivePullRequest ====== \(fileTransfer)")
        DispatchQueue.global().async {
            do {
                let nsize = 2048
                var count = ( self.imgDate.count / nsize )
                let remainder = self.imgDate.count % nsize
                if remainder != 0 {
                    count += 1
                }
                var index = 0
                let readHandle = FileHandle(forReadingAtPath: sendPath)
                while index < count {

                    let offset = index * nsize
                    readHandle?.seek(toFileOffset: UInt64(offset))
                    var data = Data()
                    if index == count - 1 {
                        data = (readHandle?.readDataToEndOfFile())!
                    }
                    else {
                        data = (readHandle?.readData(ofLength: nsize))!
                    }
                    try self.sfileTransfer.sendData(fileId: fileId, withData: data)
                    index += 1
                }
            } catch {
                print("didReceivePullRequest: error \(error)")
            }
        }

    }

    func didReceiveFileTransferData(_ fileTransfer: CarrierFileTransfer, _ fileId: String, _ data: Data) -> Bool {
        print("fileTransferStateDidChange ====== \(fileTransfer)")
        let fileManager = FileManager.default
        let exist = fileManager.fileExists(atPath: receivePath)
        if !exist {
            fileManager.createFile(atPath: receivePath, contents: nil, attributes: nil)
        }
        let writeHandle = FileHandle(forWritingAtPath: receivePath)
        writeHandle?.seek(toFileOffset: UInt64(receiveoffset))
        writeHandle?.write(data)
        receiveoffset += data.count
        if receiveoffset == receiveinfo.fileSize {
//            sfileTransfer.close()
            DispatchQueue.main.sync {
                let readHandle = FileHandle(forReadingAtPath: receivePath)
                readHandle!.seek(toFileOffset: 0)
                receiveData = (readHandle?.readDataToEndOfFile())!
                let imge = UIImage(data: receiveData)
                UIImageWriteToSavedPhotosAlbum(imge!, nil, nil, nil)
                showImage.image = imge
            }
        }
        return true
    }

}


