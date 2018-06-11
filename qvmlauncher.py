#! /usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import string
sys.path.append('/home/dmair/bin/pyqt')
from PyQt4 import QtCore, QtGui
from PyQt4.QtGui import QApplication, QDialog
from ui_vm_dlg import Ui_vm_dlg

DBG = 2
VMDIR = os.getenv('HOME') + '/.vmlauncher'

class VMDialog(QDialog):
  defaultMachine = 'pc-1.0'
  defaultCPU = 'host'
#  defaultVGA = 'cirrus'
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
  
  def calcMinTabBoxWidth(self):
    # Work through a line of material on the system tab
    myUI = self.ui
    minX = 2 * self.defaultWidgetGap

    minX += myUI.lblMachine.width()
    minX += self.defaultBuddyGap

    minX += ((myUI.lblMachine.width() * 86) / 54)
    minX += self.defaultWidgetGap

    minX += myUI.lblUUID.width()
    minX += self.defaultBuddyGap

    minX += ((myUI.lblMachine.width() * 176) / 54)

    # If the tab widget has a frame add it
    minX += myUI.vmSettings.frameSize().width() - myUI.vmSettings.width()

    return minX

  # We only need to consider some controls and an assumed gap for each
  def calcMinWidth(self):
    minX = self.calcMinTabBoxWidth()

    # Add a gap to the VM list
    minX += self.defaultWidgetGap

    # Use a ratio for space for the VM list size
    minX += minX / 2

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

    minY += myUI.buttonBox.height()
    minY += self.defaultWidgetGap

    minY += self.calcMinTabBoxHeight()

    if DBG > 0:
      print("Dialog requires height of at least " + str(minY))

    return minY

  def bestSize(self):
      return core.QSize(calcMinWidth(self), calcMinHeight(self))

  def resizeEvent(self, event):
    minX = 5
    minY = 5

    if DBG > 0:
      print("Resizing VM dialog from " + str(event.oldSize().width()) + "x" + str(event.oldSize().height()) + " to " + str(event.size().width()) + "x" + str(event.size().height()))
      
    QtGui.QDialog.resizeEvent(self, event)
    
    # Re-position the controls

  def populateVMList(self):
    """Read the filenames in the VM config file directory and place each one in the VM list box"""
    for file in os.listdir(VMDIR):
      if not file.endswith('~'):
        self.ui.vmList.addItem(file)
  
  
  def loadVMSettings(self):
    """Load the VM configuration from the selected file"""
    if DBG > 0:
      print('>>>>>>>>>>>>>>>> Loading VM settings for ' + self.fnm)
    
    if not os.path.exists(self.fnm):
      return

    f = open(self.fnm, 'r')
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

    if DBG > 1:
      print('<<<<<<<<<<<<<<<< Finished loading VM settings')
      
      
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
    
    nicID, nicOK = self.ui.nic.currentText().toInt()
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

  def __init__(self):
    if DBG > 0:
      print('KVM-QT: VM directory is ' + VMDIR)

    QDialog.__init__(self)
    
    # Setup the designer UI
    self.ui = Ui_vm_dlg()
    self.ui.setupUi(self)
    
    self.ui.machine.addItem('PC 1.0')
    self.ui.machine.addItem('PC 0.14')
    self.ui.machine.addItem('PC 0.13')
    self.ui.machine.addItem('PC 0.12')
    self.ui.machine.addItem('PC 0.11')
    self.ui.machine.addItem('PC 0.10')
    self.ui.machine.addItem('ISA PC')
    
    self.ui.vgaModel.addItem('Standard')
    self.ui.vgaModel.addItem('Cirrus')
    self.ui.vgaModel.addItem('VMWare')
    self.ui.vgaModel.addItem('QXL')
    self.ui.vgaModel.addItem('XenFB')
    self.ui.vgaModel.addItem('None')
    
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
    
    self.ui.acpi.setChecked(self.acpi)
    self.ui.hpet.setChecked(self.hpet)
    
    self.ui.soundCard.addItem('PC Speaker')
    self.ui.soundCard.addItem('Soundblaster 16')
    self.ui.soundCard.addItem('Intel AC97')
    self.ui.soundCard.addItem('Ensoniq ES1370')
    self.ui.soundCard.addItem('Intel HDA')
    
    self.ui.fdd.addItem('A')
    self.ui.fdd.addItem('B')
    
    self.ui.ide.addItem('A')
    self.ui.ide.addItem('B')
    self.ui.ide.addItem('C')
    self.ui.ide.addItem('D')
    
    self.ui.scsi.addItem('A')
    self.ui.scsi.addItem('B')
    self.ui.scsi.addItem('C')
    self.ui.scsi.addItem('D')
    self.ui.scsi.addItem('I')
    
    for nic in range(0, 10, 1):
      self.ui.nic.addItem(str(nic))
      
    for nicModel in ['NE2000 PCI', 'i82551', 'i82557b', 'i82559er', 'RTL8139', 'e1000', 'PC-NET', 'Virt I/O']:
      self.ui.nicModel.addItem(nicModel)
    
    if DBG == 0:
      self.ui.vmSettings.setCurrentIndex(0)
    
    self.populateVMList()
    self.ui.vmList.currentTextChanged.connect(self.VMChanged)
    self.ui.fdd.currentIndexChanged.connect(self.FDDChanged)
    self.ui.ide.currentIndexChanged.connect(self.IDEChanged)
    self.ui.scsi.currentIndexChanged.connect(self.SCSIChanged)
    self.ui.nic.currentIndexChanged.connect(self.NICChanged)

    self.setFixedWidth(self.calcMinWidth())
    self.setFixedHeight(self.calcMinHeight())

def main():
    app = QtGui.QApplication(sys.argv)
    
    #w = QtGui.QWidget()
    #w.resize(250, 150)
    #w.move(300, 300)
    #w.setWindowTitle('KVM Manager')
    w = VMDialog()
#    ui = Ui_vm_dlg()
#    ui.setupUi(w)
    w.show()
    
    sys.exit(app.exec_())
  
  
if __name__ == '__main__':
    main()
  

#class Ui_KVMDialog(QtGui.QDialog):
    #def setupUi(self, KVMDialog):
        #KVMDialog.setObjectName("KVMDialog")
        #KVMDialog.resize(400, 300)
        #self.buttonBox = QtGui.QDialogButtonBox(KVMDialog)
        #self.buttonBox.setGeometry(QtCore.QRect(30, 240, 341, 32))
        #self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        #self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.Ok)
        #self.buttonBox.setObjectName("buttonBox")
        #self.listView = QtGui.QListView(KVMDialog)
        #self.listView.setGeometry(QtCore.QRect(10, 40, 256, 192))
        #self.listView.setObjectName("listView")
        #self.label = QtGui.QLabel(KVMDialog)
        #self.label.setGeometry(QtCore.QRect(10, 20, 61, 18))
        #self.label.setObjectName("label")

        #self.retranslateUi(KVMDialog)
        #QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL("accepted()"), KVMDialog.accept)
        #QtCore.QObject.connect(self.buttonBox, QtCore.SIGNAL("rejected()"), KVMDialog.reject)
        #QtCore.QMetaObject.connectSlotsByName(KVMDialog)


#if __name__ == '__main__':
    #import sys
    #global app
    
    #app = QtGui.QApplication(sys.argv)

    #widget = Ui_KVMDialog
    #widget.setupUi
    #widget.show

    #sys.exit(app.exec_())
