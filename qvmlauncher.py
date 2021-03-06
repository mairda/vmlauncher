#! /usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import string
import subprocess
import random

DBG = 2

VMDIR = os.getenv('HOME') + '/.vmlauncher'
UIFILELOC="~/bin/"

from PyQt5 import QtCore, QtGui, QtWidgets
from PyQt5.QtCore import QObject, pyqtSignal, pyqtSlot
from PyQt5.QtWidgets import QApplication, QDialog, QFileDialog, QMenu, QMessageBox


class NewDiskDialog(QDialog):
    defaultWidgetMargin = 10
    defaultWidgetGap = 5
    defaultBuddyGap = 2
  
    def __init__(self):
        if DBG > 0:
            print('New Disk Dialog')

        QDialog.__init__(self)
    
        # Setup the designer UI
        self.ui = Ui_newDisk_dlg()
        self.ui.setupUi(self)
        self.ui.btnBrowse.clicked.connect(self.PickDir)
        self.setFixedWidth(self.calcMinWidth())
        self.setFixedHeight(self.calcMinHeight())    

    # We only need to consider some controls and an assumed gap for each
    def calcMinWidth(self):
        # Get the required width for the prompt and it's margins
        promptWidth = (2 * self.defaultWidgetMargin) + self.ui.lblInfo.width()

        # Use a margin (top, bottom, left, right)
        minX = 2 * self.defaultWidgetMargin
    
        # Add widget gaps for the filename line
        minX += 2 * self.defaultWidgetGap
    
        # Add the size of the filename prompt
        minX += self.ui.lblFName.width()
    
        # Add the size of the browse button
        minX += self.ui.btnBrowse.width()
    
        # Is anything left after allowing for the top prompt
        if (minX < promptWidth):
            # Use the top prompt width as the minimum
            minX = promptWidth

        if DBG > 0:
            print("New Disk Dialog requires width of at least " + str(minX))

        return minX

    # We only need to consider some controls and an assumed gap for each
    def calcMinHeight(self):
        # Top and bottom margin, plus the gap to the buttons
        minY = 3 * self.defaultWidgetMargin
        
        # Two gaps between lines of controls
        minY += 2 * self.defaultWidgetGap
        
        # Height of the top prompt
        minY += self.ui.lblInfo.height()

        # Then the size of the larger control on the Filename line
        ctrlHeight = self.ui.lblFName.height()
        tmpY = self.ui.diskFName.height()
        if ctrlHeight > tmpY:
            tmpY = ctrlHeight
            
        ctrlHeight = self.ui.btnBrowse.height()
        if ctrlHeight > tmpY:
            tmpY = ctrlHeight
            
        minY += tmpY
        
        # Then the size of the larger control on the size/format line
        ctrlHeight = self.ui.lblSz.height()
        tmpY = self.ui.sizeVal.height()
        if ctrlHeight > tmpY:
            tmpY = ctrlHeight
            
        ctrlHeight = self.ui.sizeScale.height()
        if ctrlHeight > tmpY:
            tmpY = ctrlHeight

        ctrlHeight = self.ui.fileFormat.height()
        if ctrlHeight > tmpY:
            tmpY = ctrlHeight

        minY += tmpY

        # And the height of the button box
        minY += self.ui.buttonBox.height()
        
        if DBG > 0:
            print("New Disk Dialog requires height of at least " + str(minY))

        return minY
    
    def bestSize(self):
        return core.QSize(calcMinWidth(self), calcMinHeight(self))

    def resizeEvent(self, event):
        if DBG > 0:
            print("Resizing New Disk Dialog from " + str(event.oldSize().width()) + "x" + str(event.oldSize().height()) + " to " + str(event.size().width()) + "x" + str(event.size().height()))
        
        QtWidgets.QDialog.resizeEvent(self, event)

    def PickDir(self, checked):
        hmdr = os.getenv('HOME')
        dirDlg = QFileDialog(self);
        dirDlg.setFileMode(QFileDialog.Directory);
        dirDlg.setDirectory(hmdr)
        dirDlg.setNameFilter("Select A Directory (*)")
        if dirDlg.exec_():
            selDir = dirDlg.directory()
            dirName = selDir.absolutePath()
            if dirName != "":
                self.ui.diskFName.setText(dirName)
          
    def diskFilename(self):
        return self.ui.diskFName.text()

    def diskFormat(self):
        selFmt = self.ui.fileFormat.currentText()
        if selFmt == "QCOW2":
            return "qcow2"
        else:
            return "raw"
  
    def diskSizeValue(self):
        return self.ui.sizeVal.value()
  
    def diskSizeUnits(self):
        szUnits = self.ui.sizeScale.currentText()
        if szUnits == "GB":
            return "G"
        
        return "M"

class storageContextMenuEvents(QObject):
    btnSource = 0
    sigReclick = pyqtSignal()

class VMDialog(QDialog):
    defaultMachine = 'pc-1.0'
    defaultCPU = 'host'
#    defaultVGA = 'cirrus'
    defaultVGA = 'std'
    defaultCurses = False
    defaultClock = True
    defaultACPI = True
    defaultHPET = True
    defaultSound = 'pcspk'
    defaultUUID = ''
    defaultNICModel = 'Virt I/O'
    
    defaultWidgetMargin = 10
    defaultWidgetGap = 5
    defaultBuddyGap = 2

    saveOn = False
    fnm = ''
    machine = ''
    vmName = ''
    cpuModel = 'host'
    cpus = 0
    mem = 0
    utcClock = True
    vga = defaultVGA
    curses = False
    usb = False
    acpi = defaultACPI
    hpet = defaultHPET
    sound = defaultSound
    uuid = defaultUUID

    fda = ''
    fdb = ''
    hda = ''
    hdb = ''
    hdc = ''
    hdd = ''
    sda = ''
    sdb = ''
    sdc = ''
    sdd = ''
    sdi = ''
    cdrom = ''

    nics = ['', '', '', '', '', '', '', '', '', '']
    macs = ['', '', '', '', '', '', '', '', '', '']
    vlans = ['', '', '', '', '', '', '', '', '', '']

    minFDD = 'A'
    maxFDD = 'B'
    minIDEHD = 'A'
    maxIDEHD = 'D'
    minSCSIHD = 'A'
    maxSCSIHD = 'D'
    extraSCSIHDs = ['I']
    minNICID = 0
    maxNICID = 9
    nicModels = ['NE2000 PCI', 'i82551', 'i82557b', 'i82559er', 'RTL8139', 'e1000', 'PC-NET', 'Virt I/O']

    def calcMinTabBoxWidth(self):
        # Work through a line of material on the system tab
        myUI = self.ui
        
        # Left and right margins
        minX = 2 * self.defaultWidgetGap

        # Machine controls
        minX += myUI.lblMachine.width()
        minX += self.defaultBuddyGap
        minX += myUI.machine.width()
#        minX += ((myUI.lblMachine.width() * 86) / 54)
        minX += self.defaultWidgetGap

        # UUID controls
        minX += myUI.lblUUID.width()
        minX += self.defaultWidgetGap
        minX += myUI.uuid.width()
        minX += self.defaultBuddyGap
        minX += myUI.btnGenUUID.width()
        minX += self.defaultBuddyGap

#        minX += ((myUI.lblMachine.width() * 176) / 54)

        # If the tab widget has a frame add it
        minX += myUI.vmSettings.frameSize().width() - myUI.vmSettings.width()

        if DBG > 0:
            print("Tab Box requires width of at least " + str(minX))

        return minX

    # We only need to consider some controls and an assumed gap for each
    def calcMinWidth(self):
        minX = self.calcMinTabBoxWidth()

        # Add a gap to the VM list
        minX += self.defaultWidgetGap

        # Use a ratio for space for the VM list size
        xVMList = (180 * minX) / 500
        self.ui.vmList.resize(xVMList, self.ui.vmList.height())
        if DBG > 0:
            print("VM List width of at least " + str(xVMList))
        minX += xVMList

        # Use a margin (top, bottom, left, right)
        minX += 2 * self.defaultWidgetMargin

        if DBG > 0:
            print("Dialog requires width of at least " + str(minX))

        return minX

    def calcMinTabBoxHeight(self):
        # use the System tab content
        myUI = self.ui
        minY = 2 * self.defaultWidgetGap

        minY += myUI.uuid.height()
        minY += self.defaultWidgetGap

        minY += myUI.cpuCount.height()
        minY += self.defaultWidgetGap

        minY += myUI.memMB.height()
        minY += self.defaultWidgetGap

        minY += myUI.usb.height()
        minY += self.defaultWidgetGap

        minY += myUI.acpi.height()
        minY += self.defaultWidgetGap

        minY += myUI.soundCard.height()
        minY += self.defaultWidgetGap

        # Plus the tabs themselves
        minY += myUI.vmSettings.tabBar().height()

        # If the tab widget has a frame add it
        minY += myUI.vmSettings.frameSize().height() - myUI.vmSettings.height()

        return minY

    # We only need to consider some controls and an assumed gap for each
    def calcMinHeight(self):
        # Use a margin (top, bottom, left, right)
        minY = 2 * self.defaultWidgetMargin

        # Work through the surface material on the dialog
        myUI = self.ui
        minY += myUI.lblSelectedVM.height()
        minY += self.defaultWidgetGap

        minY += myUI.lnFileConfigBreak.height()
        minY += self.defaultWidgetGap

        minY += myUI.vmName.height()
        minY += self.defaultWidgetGap

        minY += myUI.lblSettings.height()
        minY += self.defaultWidgetGap

        #minY += myUI.buttonBox.height()
        minY += myUI.buttonFrame.height()
        minY += self.defaultWidgetGap

        minY += self.calcMinTabBoxHeight()

        if DBG > 0:
            print("Dialog requires height of at least " + str(minY))

        return minY

    def bestSize(self):
        return core.QSize(calcMinWidth(self), calcMinHeight(self))

    def resizeEvent(self, event):
        if DBG > 0:
            print("Resizing VM dialog from " + str(event.oldSize().width()) + "x" + str(event.oldSize().height()) + " to " + str(event.size().width()) + "x" + str(event.size().height()))
        
        QtWidgets.QDialog.resizeEvent(self, event)
        
    def populateVMList(self):
        #"""Read the filenames in the VM config file directory and place each one in the VM list box"""
        if not os.path.exists(VMDIR):
            return

        for file in os.listdir(VMDIR):
            if not file.endswith('~'):
                self.ui.vmList.addItem(file)
  
    def loadVMSettings(self):
        #"""Load the VM configuration from the selected file"""
        if DBG > 0:
            print('>>>>>>>>>>>>>>>> Loading VM settings for ' + self.fnm)
        
        if not os.path.exists(self.fnm):
            return

        with open(self.fnm, 'r') as f:
            self.machine = self.defaultMachine
            self.cpuModel = self.defaultCPU
            self.utcClock = self.defaultClock
            self.vga = self.defaultVGA
            self.curses = self.defaultCurses
            self.acpi = self.defaultACPI
            self.hpet = self.defaultHPET
            self.sound = self.defaultSound
            self.uuid = self.defaultUUID
            self.fda = ''
            self.fdb = ''
            self.hda = ''
            self.hdb = ''
            self.hdc = ''
            self.hdd = ''
            self.sda = ''
            self.sdb = ''
            self.sdc = ''
            self.sdd = ''
            self.sdi = ''
            self.cdrom = ''
            
            for line in f:
                line = line.strip('\n')
                if DBG > 1:
                    print(line)
                if line.startswith('#'):
                    continue
                if line.find('noacpi') == 0:
                    self.acpi = False
                if line.startswith('cdrom='):
                    self.cdrom = line[6:]
                if line.startswith('cpu='):
                    self.cpuModel = line[4:]
                if line.startswith('cpus='):
                    self.cpus = line[5:]
                if line.find('curses') == 0:
                    self.curses = True
                if line.startswith('fda='):
                    self.fda = line[4:]
                if line.startswith('fdb='):
                    self.fdb = line[4:]
                if line.startswith('hda='):
                    self.hda = line[4:]
                if line.startswith('hdb='):
                    self.hdb = line[4:]
                if line.startswith('hdc='):
                    self.hdc = line[4:]
                if line.startswith('hdd='):
                    self.hdd = line[4:]
                if line.find('nohpet') == 0:
                    self.hpet = False
                if line.find('localtime') == 0:
                    self.utcClock = False
                if line.startswith('mac') and line[4:5] == '=':
                    nicNum = eval(line[3:4])
                    self.macs[nicNum] = line[5:]
                if line.startswith('machine='):
                    self.machine = line[8:]
                if line.startswith('mem='):
                    self.mem = line[4:]
                if line.startswith('name='):
                    self.vmName = line[5:]
                if line.startswith('nic') and line[4:5] == '=':
                    nicNum = eval(line[3:4])
                    self.nics[nicNum] = line[5:]
                if line.find('nousb') == 0:
                    self.usb = False
                if line.startswith('sda='):
                    self.sda = line[4:]
                if line.startswith('sdb='):
                    self.sdb = line[4:]
                if line.startswith('sdc='):
                    self.sdc = line[4:]
                if line.startswith('sdd='):
                    self.sdd = line[4:]
                if line.startswith('sdi='):
                    self.sdi = line[4:]
                if line.startswith('smp='):
                    self.cpus = line[4:]
                if line.startswith('soundhw='):
                    self.sound = line[8:]
                if line.find('usb') == 0:
                    self.usb = True
                if line.startswith('uuid='):
                    self.uuid = line[5:]
                if line.startswith('vga='):
                    self.vga = line[4:]
                if line.startswith('vlan') and line[5:6] == '=':
                    nicNum = eval(line[4:5])
                    self.vlans[nicNum] = line[6:]
                self.enableSaveButton(False)

            f.close()

        if DBG > 1:
            print('<<<<<<<<<<<<<<<< Finished loading VM settings')

    @pyqtSlot(bool)
    def saveClicked(self, checked):
        self.saveVMSettings()

    def saveVMSettings(self):
        #"""Load the VM configuration from the selected file"""
        if DBG > 0:
            print('>>>>>>>>>>>>>>>> Saving VM settings for ' + self.fnm)

        self.fnm = self.ui.vmFileName.text()
        if self.fnm != "":
            self.ui.vmFileName.setFocus(True)

            with open(self.fnm, 'w') as f:
                self.vmName = self.ui.vmName.text()
                if len(self.vmName) > 0:
                    f.write('name=' + self.vmName + '\n')

                self.machine = self.getQEMUMachine()
                if self.machine != self.defaultMachine:
                    f.write('machine=' + self.machine + '\n')

                self.cpuModel = self.getQEMUCPUModel()
                if self.machine != self.defaultMachine:
                    f.write('cpu=' + self.machine + '\n')

                self.cpus = self.ui.cpuCount.value()
                f.write('cpus=' + str(self.cpus) + '\n')

                self.mem = self.ui.memMB.value()
                f.write('mem=' + str(self.mem) + '\n')

                if (not self.ui.utcClock.isChecked()) and (self.ui.localClock.isChecked()):
                    f.write('localtime\n')

                self.vga = self.getQEMUVGA()
                if self.vga != self.defaultVGA:
                    f.write('vga=' + self.vga + '\n')

                if not self.ui.acpi.isChecked():
                    f.write('noacpi\n')

                if not self.ui.hpet.isChecked():
                    f.write('nohpet\n')

                self.sound = self.getQEMUSound()
                if self.sound != self.defaultSound:
                    f.write('soundhw=' + self.sound + '\n')

                if self.ui.usb.isChecked():
                    f.write('usb\n')
                else:
                    f.write('nousb\n')

                self.uuid = self.ui.uuid.text()
                if len(self.uuid) == 36:
                    f.write('uuid=' + self.uuid + '\n')

                if len(self.fda) > 0:
                    f.write('fda=' + self.fda + '\n')
                if len(self.fdb) > 0:
                    f.write('fdb=' + self.fda + '\n')

                if len(self.hda) > 0:
                    f.write('hda=' + self.hda + '\n')
                if len(self.hdb) > 0:
                    f.write('hdb=' + self.hdb + '\n')
                if (len(self.cdrom) == 0) and (len(self.hdc) > 0):
                    f.write('hdc=' + self.hdc + '\n')
                elif len(self.cdrom) > 0:
                    f.write('cdrom=' + self.cdrom + '\n')
                if len(self.hdd) > 0:
                    f.write('hdd=' + self.hdd + '\n')

                if len(self.sda) > 0:
                    f.write('sda=' + self.sda + '\n')
                if len(self.sdb) > 0:
                    f.write('sdb=' + self.sdb + '\n')
                if len(self.sdc) > 0:
                    f.write('sdc=' + self.sdc + '\n')
                if len(self.sdd) > 0:
                    f.write('sdd=' + self.sdd + '\n')
                if len(self.sdi) > 0:
                    f.write('sdi=' + self.sdi + '\n')

                self.curses = self.ui.curses.isChecked()
                if self.curses:
                    f.write('curses\n')

                for nicNum in range(self.minNICID, self.maxNICID + 1, 1):
                    if (len(self.macs[nicNum]) > 0) or (len(self.nics[nicNum]) > 0) or (len(self.vlans[nicNum]) > 0):
                        f.write('mac' + str(nicNum) + '=' + self.macs[nicNum] + '\n')
                        f.write('nic' + str(nicNum) + '=' + self.nics[nicNum] + '\n')
                        f.write('vlan' + str(nicNum) + '=' + self.vlans[nicNum] + '\n')

                f.close()

            if os.path.exists(self.fnm):
                self.ui.btnSave.setEnabled(False)
            else:
                QMessageBox.critical(self, 'Error saving VM', "Failed to save VM configuration file: " + self.fnm, QMessageBox.Ok)
                return

            self.ui.vmFileName.setFocus(True)

        if DBG > 1:
            print('<<<<<<<<<<<<<<<< Finished saving VM settings')
        return
      
    def FDDChanged(self, newFDD):
        """The slot for the FDD combobox box currentIndexChanged signal"""
        fddID = self.ui.fdd.currentText()
        if DBG > 1:
            print("Changing FD drive to " + fddID)
        if fddID == 'B':
            self.ui.fddPath.setText(self.fdb)
        else:
            self.ui.fddPath.setText(self.fda)
      
    def IDEChanged(self, newHDD):
        """The slot for the IDE HDD combobox box currentIndexChanged signal"""
        hddID = self.ui.ide.currentText()
        if DBG > 1:
            print("Changing IDE drive to " + hddID)
        if hddID == 'D':
            self.ui.idePath.setText(self.hdd)
        else:
            if hddID == 'C':
                self.ui.idePath.setText(self.hdc)
            else:
                if hddID == 'B':
                    self.ui.idePath.setText(self.hdb)
                else:
                    self.ui.idePath.setText(self.hda)

          
    def SCSIChanged(self, newHDD):
        """The slot for the SCSI HDD combobox box currentIndexChanged signal"""
        hddID = self.ui.scsi.currentText()
        if DBG > 1:
            print("Changing SCSI drive to " + hddID)
        if hddID == 'I':
            self.ui.scsiPath.setText(self.sdi)
        else:
            if hddID == 'D':
                self.ui.scsiPath.setText(self.sdd)
            else:
                if hddID == 'C':
                    self.ui.scsiPath.setText(self.sdc)
                else:
                    if hddID == 'B':
                        self.ui.scsiPath.setText(self.sdb)
                    else:
                        self.ui.scsiPath.setText(self.sda)
          
    def NICChanged(self, newNIC):
        """The slot for the NIC combobox box currentIndexChanged signal"""
        
        if newNIC > 9:
            return

        nicID = int(self.ui.nic.currentText())
        if DBG > 1:
            print("Changing NIC to " + str(nicID))
        self.ui.mac.setText(self.macs[nicID])
        self.ui.vlan.setText(self.vlans[nicID])
        nicModel = self.defaultNICModel
        if self.nics[nicID] == 'ne2k_pci':
            nicModel = 'NE2000 PCI'
        if self.nics[nicID] == 'i82551':
            nicModel = 'i82551'
        if self.nics[nicID] == 'i82557b':
            nicModel = 'i82557b'
        if self.nics[nicID] == 'i82559er':
            nicModel = 'i82559er'
        if self.nics[nicID] == 'rtl8139':
            nicModel = 'RTL8139'
        if self.nics[nicID] == 'e1000':
            nicModel = 'e1000'
        if self.nics[nicID] == 'pcnet':
            nicModel = 'PC-NET'
        if self.nics[nicID] == 'virtio':
            nicModel = 'Virt I/O'

        if self.nics[nicID] != '':
            inic = self.ui.nicModel.findText(nicModel, QtCore.Qt.MatchFixedString)
        else:
            inic = self.ui.nicModel.findText(self.defaultNICModel, QtCore.Qt.MatchFixedString)
        if inic == -1:
            inic = 0
        self.ui.nicModel.setCurrentIndex(inic)
    
    def VMChanged(self, newVM):
        """The slot for the VM list box currentTextChanged signal"""
        self.fnm = VMDIR + '/' + newVM;
        self.ui.vmFileName.setText(self.fnm)
        self.loadVMSettings()
        self.ui.vmName.setText(self.vmName)
    
        imachine = self.ui.machine.findText(self.machine.replace('-', ' '), QtCore.Qt.MatchFixedString)
        if imachine == -1:
            if DBG > 0:
                print('Unrecognized machine ' + self.machine + ' used in configuration')
            imachine = self.ui.machine.findText(self.defaultMachine, QtCore.Qt.MatchFixedString)
        if imachine < 0:
            imachine = 0
        self.ui.machine.setCurrentIndex(imachine)
    
        self.ui.cpuCount.setValue(eval(self.cpus))
        icpu = self.ui.cpuModel.findText(self.cpuModel.replace('_', ' '), QtCore.Qt.MatchFixedString)
        if icpu == -1:
            if DBG > 0:
                print('Unrecognized cpu model ' + self.cpuModel + ' used in configuration')
            icpu = self.ui.cpuModel.findText(self.defaultCPU, QtCore.Qt.MatchFixedString)
        if icpu == -1:
            icpu = 0
        self.ui.cpuModel.setCurrentIndex(icpu)
    
        self.ui.memMB.setValue(eval(self.mem))
        self.ui.utcClock.setChecked(self.utcClock)
        self.ui.localClock.setChecked(not self.utcClock)
        vgaModel = self.vga
        if vgaModel == 'std':
            vgaModel = 'Standard'
        ivga = self.ui.vgaModel.findText(vgaModel, QtCore.Qt.MatchFixedString)
        if ivga == -1:
            if DBG > 0:
                print('Unrecognized vga model ' + self.vga + ' used in configuration')
        vgaModel = self.defaultVGA
        ivga = self.ui.vgaModel.findText(vgaModel, QtCore.Qt.MatchFixedString)
        if ivga == -1:
            ivga = 0
        self.ui.vgaModel.setCurrentIndex(ivga)
    
        soundModel = self.defaultSound
        if self.sound == 'pcspk':
            soundModel = 'PC Speaker'
        if self.sound == 'sb16':
            soundModel = 'Soundblaster 16'
        if self.sound == 'ac97':
            soundModel = 'Intel AC97'
        if self.sound == 'es1370':
            soundModel = 'Ensoniq ES1370'
        if self.sound == 'hda':
            soundModel = 'Intel HDA'
        isound = self.ui.soundCard.findText(soundModel, QtCore.Qt.MatchFixedString)
        if isound == -1:
            if DBG > 0:
                print('Unrecognized sound card model ' + self.sound + ' used in configuration')
            soundModel = self.defaultSound
        isound = self.ui.soundCard.findText(soundModel, QtCore.Qt.MatchFixedString)
        if isound == -1:
            isound = 0
        self.ui.soundCard.setCurrentIndex(isound)

        self.ui.curses.setChecked(self.curses)
        self.ui.usb.setChecked(self.usb)
        self.ui.acpi.setChecked(self.acpi)
        self.ui.hpet.setChecked(self.hpet)
        self.ui.uuid.setText(self.uuid)

        firstDisk = 'A'
        if self.fda == '':
            firstDisk = 'B'
        if self.fdb == '':
            firstDisk = 'A'
        idsk = self.ui.fdd.findText(firstDisk, QtCore.Qt.MatchFixedString)
        if idsk == -1:
            idsk = 0
        selfsig = (idsk == self.ui.fdd.currentIndex())
        self.ui.fdd.setCurrentIndex(idsk)
        if selfsig:
            self.FDDChanged(idsk)

        self.ui.cdromPath.setText(self.cdrom)
        if self.cdrom != '' and self.hdc != '':
            print("CD-ROM and hdc values specified in configuration, ignoring hdc")
        if self.cdrom != '':
            self.hdc = self.cdrom

        firstDisk = 'A'
        if self.hda == '':
            firstDisk = 'B';
            if self.hdb == '':
                firstDisk = 'C'
                if self.hdc == '':
                    firstDisk = 'D'
                    if self.hdd == '':
                        firstDisk = 'A'
        idsk = self.ui.ide.findText(firstDisk, QtCore.Qt.MatchFixedString)
        if idsk == -1:
            idsk = 0
        selfsig = (idsk == self.ui.ide.currentIndex())
        self.ui.ide.setCurrentIndex(idsk)
        if selfsig:
            self.IDEChanged(idsk)

        firstDisk = 'A'
        if self.sda == '':
            firstDisk = 'B';
            if self.sdb == '':
                firstDisk = 'C'
                if self.sdc == '':
                    firstDisk = 'D'
                    if self.sdd == '':
                        firstDisk = 'I'
                        if self.sdi == '':
                            firstDisk = 'A'
        idsk = self.ui.scsi.findText(firstDisk, QtCore.Qt.MatchFixedString)
        if idsk == -1:
            idsk = 0
        selfsig = (idsk == self.ui.scsi.currentIndex())
        self.ui.scsi.setCurrentIndex(idsk)
        if selfsig:
            self.SCSIChanged(idsk)

        for firstMAC in range(0, 11, 1):
            if firstMAC == 10:
                break;
            if DBG > 2:
                print("Testing MAC for NIC " + str(firstMAC) + " (" + self.macs[firstMAC] + ")")
            if self.macs[firstMAC] != '':
                break;
        for firstVLAN in range(0, 11, 1):
            if firstVLAN == 10:
                break;
            if DBG > 2:
                print("Testing VLAN for NIC " + str(firstVLAN) + " (" + self.vlans[firstVLAN] + ")")
            if self.vlans[firstVLAN] != '':
                break;
        for firstNIC in range(0, 11, 1):
            if firstNIC == 10:
                break;
            if DBG > 2:
                print("Testing settings for NIC " + str(firstNIC) + " (" + self.nics[firstNIC] + ")")
            if self.nics[firstNIC] != '':
                break;
        if firstMAC < firstNIC:
            firstNIC = firstMAC
        if firstVLAN < firstNIC:
            firstNIC = firstVLAN
        if firstNIC == 10:
            firstNIC = 0
        inic = self.ui.nic.findText(str(firstNIC))
        if inic == -1:
            inic = 0
        selfsig = (inic == self.ui.nic.currentIndex())
        self.ui.nic.setCurrentIndex(inic)
        if selfsig:
            self.NICChanged(inic)

        self.enableSaveButton(False)

    def enableSaveButton(self, btnOn):
        self.SaveOn = btnOn
        self.ui.btnSave.setEnabled(btnOn)

    def filenameChanged(self, text):
        if not self.saveOn:
            self.enableSaveButton(True)

    def VMNameChanged(self, text):
        if not self.saveOn:
            self.enableSaveButton(True)

    def UUIDChanged(self, text):
        if not self.saveOn:
            self.enableSaveButton(True)

    def cdromChanged(self, text):
        if not self.saveOn:
            self.enableSaveButton(True)

    def cpusChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def CPUModelChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def memSizeChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def VGAModelChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def SoundCardChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def ClockToggled(self, checked):
        if not self.saveOn:
            self.enableSaveButton(True)

    def USBChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def ACPIChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def HPETChanged(self, i):
        if not self.saveOn:
            self.enableSaveButton(True)

    def VLANChanged(self, text):
        if not self.saveOn:
            self.enableSaveButton(True)

    def generateUUID(self, generateUUID):
        random.seed()
        a = random.randrange(0, 2147483647)
        b = random.randrange(0, 65535)
        c = random.randrange(0, 65535)
        d = random.randrange(0, 65535)
        e = random.randrange(0, 65535)
        f = random.randrange(0, 2147483647)
        newUUID = "{0:0{1}x}".format(a, 8)
        newUUID += "-"
        newUUID += "{0:0{1}x}".format(b, 4)
        newUUID += "-"
        newUUID += "{0:0{1}x}".format(c, 4)
        newUUID += "-"
        newUUID += "{0:0{1}x}".format(d, 4)
        newUUID += "-"
        newUUID += "{0:0{1}x}".format(e, 4)
        newUUID += "{0:0{1}x}".format(f, 8)
        if len(newUUID) == 36:
            self.uuid = newUUID
            self.ui.uuid.setText(self.uuid)
            self.ui.uuid.setFocus(True)
        else:
            print "ERROR: generateUUID creates UUID with length " + str(len(newUUID)) + ": " + newUUID
#		$uuid = sprintf("%08x-%04x-%04x-%04x-%04x%08x", 
#				rand(2147483647),
#				rand(65535),
#				rand(65535),
#				rand(65535),
#				rand(65535),
#				rand(2147483647));
        
        return

    def PickDisk(self, diskType):
        hmdr = os.getenv('HOME')

        if diskType == -1:
            diskTextCtrl = self.ui.fddPath
            filePrompt = "Select Floppy Disk/Image"
            fileFilter = "FDD (*)"
        elif diskType == -2:
            diskTextCtrl = self.ui.cdromPath
            filePrompt = "Select Optical Disk/Image"
            fileFilter = "CD/DVD (*.iso *)"
        elif diskType == 1:
            diskTextCtrl = self.ui.idePath
            filePrompt = "Select IDE Disk/Image"
            fileFilter = "IDE HDD (*.qcow2)"
        elif diskType == 2:
            diskTextCtrl = self.ui.scsiPath
            filePrompt = "Select SCSI Disk/Image"
            fileFilter = "SCSI HDD (*.qcow2)"
        else:
            return

        fname, fltr = QFileDialog.getOpenFileName(self, filePrompt, hmdr, fileFilter)
        if fname != "":
            diskTextCtrl.setText(fname)

        diskTextCtrl.setFocus(True)

    def PickFloppy(self, checked):
        self.PickDisk(-1)

    def PickCD(self, checked):
        self.PickDisk(-2)

    def PickIDE(self, checked):
        self.PickDisk(1)

    def PickSCSI(self, checked):
        self.PickDisk(2)

    def createNewDisk(self, iface):
        w = NewDiskDialog()
        if iface == 1:
            w.setWindowTitle('Create new virtual IDE Disk')
        elif iface == 2:
            w.setWindowTitle('Create new virtual SCSI Disk')
        else:
            return

        if w.exec_():
            fname = w.diskFilename()
            if fname == "":
                QMessageBox.warning(self, 'No filename', "You must specify a filename to create a virtual disk", QMessageBox.Ok)
                return

            # OK pressed, create the virtual HD file
            createArgs = ['qemu-img', 'create', '-f', w.diskFormat(), fname, str(w.diskSizeValue()) + w.diskSizeUnits()]
            createProc = subprocess.call(createArgs)
            if not os.path.exists(fname):
                QMessageBox.critical(self, 'Error creating disk', "Failed to create a virtual disk file: " + fname, QMessageBox.Ok)
                return
            if iface == 1:
                self.ui.idePath.setText(fname)
            elif iface == 2:
                self.ui.scsiPath.setText(fname)

    def eraseDisk(self, iface):
        if iface == 1:
            focFName = self.ui.idePath.text()
        elif iface == 2:
            focFName = self.ui.scsiPath.text()
        else:
            return False

        delOK = QMessageBox.question(self, 'Delete', "Press Yes to erase file: " + focFName + "?", QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if delOK == QMessageBox.Yes:
            os.remove(focFName)
            if os.path.exists(focFName):
                QMessageBox.critical(self, 'Error erasing file', "Failed to erase virtual disk file: " + focFName, QMessageBox.Ok)
                return False
            if (iface == 1) or (iface == 2):
                self.clearDiskPathText(iface)
            return True
        return False

    def clearDiskPathText(self, iface):
        if iface == -1:
            self.ui.fddPath.setText("")
            self.ui.fddPath.setFocus(True)
        elif iface == -2:
            self.ui.cdromPath.setText("")
            self.ui.cdromPath.setFocus(True)
        elif iface == 1:
            self.ui.idePath.setText("")
            self.ui.idePath.setFocus(True)
        elif iface == 2:
            self.ui.scsiPath.setText("")
            self.ui.scsiPath.setFocus(True)

    def contextMenuEvent(self, event):
        btnSource = 0
        btnPairText = ""
        refocusObj = self.ui.vmFileName
        focObj = self.focusWidget()
        focObjName = focObj.objectName()
        if DBG > 0:
            print('  Context Menu Event for ' + focObjName)

        if focObjName == "btnIDEDisk":
            btnSource = 1
            btnPairText = self.ui.idePath.text()
            defRef = self.ui.idePath
        elif focObjName == "btnSCSIDisk":
            btnSource = 2
            btnPairText = self.ui.scsiPath.text()
            defRef = self.ui.scsiPath
        elif focObjName == "btnFloppy":
            btnSource = -1
            btnPairText = self.ui.fddPath.text()
            defRef = self.ui.fddPath
        elif focObjName == "btnOpticalDisk":
            btnSource = -2
            btnPairText = self.ui.cdromPath.text()
            defRef = self.ui.cdromPath

        if btnSource != 0:
            menu = QMenu(focObj)
            newDisk = menu.addAction("New");
            newDisk.setEnabled(btnSource > 0)
            browseDisk = menu.addAction("Browse")
            delDisk = menu.addAction("Erase")
            delDisk.setEnabled((btnSource > 0) and (btnPairText != ""))
            clearDisk = menu.addAction("Clear")
            clearDisk.setEnabled(btnPairText != "")
            action = menu.exec_(self.mapToGlobal(event.pos()))
            if action == newDisk:
                if (btnSource != 1) and (btnSource != 2):
                    return
                refocusObj = defRef
                self.createNewDisk(btnSource)
            elif action == browseDisk:
                if DBG > 0:
                    print("Emitting re-clicking storage button signal for " + str(btnSource) + " in context menu event")

                self.storageReclicker.btnSource = btnSource
                self.storageReclicker.sigReclick.emit()

                if DBG > 0:
                    print("Re-click storage button signal emitted for " + str(btnSource) + " in context menu event")

                return
            elif action == delDisk:
                if self.eraseDisk(btnSource):
                    refocusObj = self.focusWidget()
            elif action == clearDisk:
                self.clearDiskPathText(btnSource)
                refocusObj = self.focusWidget()
            else:
                # Showed the menu but no action taken
                refocusObj = defRef
        else:
            # Doing nothing, don't change focus
            return

        # Reset focus to something other than the buttons
        refocusObj.setFocus(True)

    # Use an internal event to take a "browse" option from the storage button
    # context menus and send it to the window to do the effect of the click
    def reClickStorageBtn(self):
        if DBG > 0:
            print("Servicing re-click event for button " + str(self.storageReclicker.btnSource))

        if self.storageReclicker.btnSource == -1:
            self.ui.btnFloppy.click()
        elif self.storageReclicker.btnSource == -2:
            self.ui.btnOpticalDisk.click()
        elif self.storageReclicker.btnSource == 1:
            self.ui.btnIDEDisk.click()
        elif self.storageReclicker.btnSource == 2:
            self.ui.btnSCSIDisk.click()

        if DBG > 0:
            print("Completed re-click event for button " + str(self.storageReclicker.btnSource))

    def getQEMUMachine(self):
        theMachine = self.ui.machine.currentText()
        if theMachine == 'PC 1.0':
            theMachine = 'pc-1.0'
        elif theMachine == 'PC 0.14':
            theMachine = 'pc-0.14'
        elif theMachine == 'PC 0.13':
            theMachine = 'pc-0.13'
        elif theMachine == 'PC 0.12':
            theMachine = 'pc-0.12'
        elif theMachine == 'PC 0.11':
            theMachine = 'pc-0.11'
        elif theMachine == 'PC 0.10':
            theMachine = 'pc-0.10'
        elif theMachine == 'ISA PC':
            theMachine = 'isapc'
        else:
            theMachine = 'pc-1.0'

        return theMachine

    # PC Model list
    def initMachineList(self):
        self.ui.machine.addItem('PC 1.0')
        self.ui.machine.addItem('PC 0.14')
        self.ui.machine.addItem('PC 0.13')
        self.ui.machine.addItem('PC 0.12')
        self.ui.machine.addItem('PC 0.11')
        self.ui.machine.addItem('PC 0.10')
        self.ui.machine.addItem('ISA PC')

    def getQEMUVGA(self):
        theVGA = self.ui.vgaModel.currentText()
        theVGA = theVGA.decode('utf-8').lower()

        return theVGA

    # VGA controller list
    def initVGAList(self):
        self.ui.vgaModel.addItem('Standard')
        self.ui.vgaModel.addItem('Cirrus')
        self.ui.vgaModel.addItem('VMWare')
        self.ui.vgaModel.addItem('QXL')
        self.ui.vgaModel.addItem('XenFB')
        self.ui.vgaModel.addItem('None')

    def getQEMUCPUModel(self):
        theCPU = self.ui.cpuModel.currentText()
        if theCPU == 'Opteron G1':
            theCPU = 'Opteron_G1'
        elif theCPU == 'Opteron G2':
            theCPU = 'Opteron_G2'
        elif theCPU == 'Opteron G3':
            theCPU = 'Opteron_G3'
        elif theCPU == 'Athlon':
            theCPU = 'athlon'
        elif theCPU == 'Pentium':
            theCPU = 'pentium'
        elif theCPU == 'Pentium 2':
            theCPU = 'pentium2'
        elif theCPU == 'Pentium 3':
            theCPU = 'pentium3'
        elif theCPU == 'Core Duo':
            theCPU = 'coreduo'
        elif theCPU == 'Core2 Duo':
            theCPU = 'core2duo'
        elif theCPU == 'PC 0.10':
            theCPU = 'pc-0.10'
        elif theCPU == '':
            theCPU = 'host'

        return theCPU

    # CPU model list
    def initCPUModelList(self):
        self.ui.cpuModel.addItem('host')
        self.ui.cpuModel.addItem('Opteron G3')
        self.ui.cpuModel.addItem('Opteron G2')
        self.ui.cpuModel.addItem('Opteron G1')
        self.ui.cpuModel.addItem('Nehalem')
        self.ui.cpuModel.addItem('Penryn')
        self.ui.cpuModel.addItem('Conroe')
        self.ui.cpuModel.addItem('n270')
        self.ui.cpuModel.addItem('Athlon')
        self.ui.cpuModel.addItem('Pentium 3')
        self.ui.cpuModel.addItem('Pentium 2')
        self.ui.cpuModel.addItem('Pentium')
        self.ui.cpuModel.addItem('486')
        self.ui.cpuModel.addItem('Core Duo')
        self.ui.cpuModel.addItem('kvm32')
        self.ui.cpuModel.addItem('qemu32')
        self.ui.cpuModel.addItem('kvm64')
        self.ui.cpuModel.addItem('qemu64')
        self.ui.cpuModel.addItem('Core2 Duo')
        self.ui.cpuModel.addItem('phenom')

    def getQEMUSound(self):
        theSound = self.ui.soundCard.currentText()
        if theSound == 'PC Speaker':
            theSound = 'pcspk'
        elif theSound == 'Soundblaster 16':
            theSound = 'sb16'
        elif theSound == 'Intel AC97':
            theSound = 'ac97'
        elif theSound == 'Ensoniq ES1370':
            theSound = 'es1370'
        elif theSound == 'Intel HDA':
            theSound = 'hda'
        else:
            theSound = self.defaultSound

        return theSound

    # Sound card list
    def initSoundCardList(self):
        self.ui.soundCard.addItem('PC Speaker')
        self.ui.soundCard.addItem('Soundblaster 16')
        self.ui.soundCard.addItem('Intel AC97')
        self.ui.soundCard.addItem('Ensoniq ES1370')
        self.ui.soundCard.addItem('Intel HDA')

    # Floppy disk drive list
    def initFDDList(self):
        for fddID in range(ord(self.minFDD), ord(self.maxFDD) + 1, 1):
            self.ui.fdd.addItem(chr(fddID))

    # IDE HDD list
    def initIDEList(self):
        for ideID in range(ord(self.minIDEHD), ord(self.maxIDEHD) + 1, 1):
            self.ui.ide.addItem(chr(ideID))

    # SCSI HDD list
    def initSCSIList(self):
        for scsiID in range(ord(self.minSCSIHD), ord(self.maxSCSIHD) + 1, 1):
            self.ui.scsi.addItem(chr(scsiID))

        for scsiDisk in self.extraSCSIHDs:
            self.ui.scsi.addItem(scsiDisk)

    def initNICIDList(self):
        for nic in range(self.minNICID, self.maxNICID + 1, 1):
            self.ui.nic.addItem(str(nic))

    def initNICModelList(self):
        for nicModel in self.nicModels:
            self.ui.nicModel.addItem(nicModel)

    def __init__(self):
        if DBG > 0:
            print('QT VM Launcher: VM directory is ' + VMDIR)

        QDialog.__init__(self)

        # Setup the designer UI
        self.ui = Ui_vm_dlg()
        self.ui.setupUi(self)

        self.initMachineList()
        self.initVGAList()
        self.initCPUModelList()

        self.ui.acpi.setChecked(self.acpi)
        self.ui.hpet.setChecked(self.hpet)

        self.initSoundCardList()

        self.initFDDList()
        self.initIDEList()
        self.initSCSIList()

        self.initNICIDList()
        self.initNICModelList()

        if DBG == 0:
            self.ui.vmSettings.setCurrentIndex(0)
        
        self.populateVMList()

        # Connect events to slots
        self.ui.btnGenUUID.clicked.connect(self.generateUUID)
        self.ui.btnFloppy.clicked.connect(self.PickFloppy)
        self.ui.btnOpticalDisk.clicked.connect(self.PickCD)
        self.ui.btnIDEDisk.clicked.connect(self.PickIDE)
        self.ui.btnSCSIDisk.clicked.connect(self.PickSCSI)
        self.ui.vmList.currentTextChanged.connect(self.VMChanged)
        
        # These cause the Save button to come on if something changes but not
        # if an entry is loaded from the VM list (is in a saved state)
        self.ui.fdd.currentIndexChanged.connect(self.FDDChanged)
        self.ui.ide.currentIndexChanged.connect(self.IDEChanged)
        self.ui.scsi.currentIndexChanged.connect(self.SCSIChanged)
        self.ui.nic.currentIndexChanged.connect(self.NICChanged)
        self.ui.vmFileName.textChanged.connect(self.filenameChanged)
        self.ui.vmName.textChanged.connect(self.VMNameChanged)
        self.ui.uuid.textChanged.connect(self.UUIDChanged)
        self.ui.cdromPath.textChanged.connect(self.cdromChanged)
        self.ui.cpuCount.valueChanged.connect(self.cpusChanged)
        self.ui.cpuModel.currentIndexChanged.connect(self.CPUModelChanged)
        self.ui.memMB.valueChanged.connect(self.memSizeChanged)
        self.ui.vgaModel.currentIndexChanged.connect(self.VGAModelChanged)
        self.ui.soundCard.currentIndexChanged.connect(self.SoundCardChanged)
        self.ui.utcClock.toggled.connect(self.ClockToggled)
        self.ui.localClock.toggled.connect(self.ClockToggled)
        self.ui.usb.stateChanged.connect(self.USBChanged)
        self.ui.acpi.stateChanged.connect(self.ACPIChanged)
        self.ui.hpet.stateChanged.connect(self.HPETChanged)
        self.ui.vlan.textChanged.connect(self.VLANChanged)
        self.ui.btnSave.clicked.connect(self.saveClicked)

        # Create a signal for the asynchronous re-click from storage button context menu
        self.storageReclicker = storageContextMenuEvents()
        self.storageReclicker.sigReclick.connect(self.reClickStorageBtn, QtCore.Qt.QueuedConnection)

        self.enableSaveButton(self.saveOn)

        # Fit content and make fixed size
        self.setFixedWidth(self.calcMinWidth())
        self.setFixedHeight(self.calcMinHeight())    

# Global configuration
def loadSettings():
    global VMDIR
    global UIFILELOC

    settingsFile = os.getenv('HOME') + '/.vmlauncher.cfg'
    if os.path.exists(settingsFile):
        if DBG > 1:
            print(" Processing global settings in " + settingsFile)

        f = open(settingsFile, 'r')
        for line in f:
            line = line.strip('\n')
            if DBG > 1:
                print("  " + line)
            if line.startswith('vmconfigsdir='):
                VMDIR = line[13:]
            if line.startswith('uifileloc='):
                UIFILELOC=line[10:]
    else:
        # Default
        VMDIR = '~/.vmlauncher'
        UIFILELOC = '~/bin'

    # Make things directory entry names
    if VMDIR.endswith('/'):
        VMDIR = VMDIR[0:len(VMDIR) - 1]
    if UIFILELOC.endswith('/'):
        UIFILELOC = UIFILELOC[0:len(UIFILELOC) - 1]

    # Replace tilde with the home directory name
    VMDIR = VMDIR.replace('~', os.getenv('HOME'))
    UIFILELOC = UIFILELOC.replace('~', os.getenv('HOME'))

    if DBG > 1:
        print(" VM Config File Directory is: " + VMDIR)
        print(" UI Design Directory is: " + UIFILELOC)

def main():
    global Ui_vm_dlg
    global Ui_newDisk_dlg

    loadSettings()

    sys.path.append(UIFILELOC)
    from ui_vm_dlg import Ui_vm_dlg
    from newdiskdlg import Ui_newDisk_dlg

    app = QtWidgets.QApplication(sys.argv)

    w = VMDialog()
    w.show()
    
    sys.exit(app.exec_())
  
if __name__ == '__main__':
    main()
