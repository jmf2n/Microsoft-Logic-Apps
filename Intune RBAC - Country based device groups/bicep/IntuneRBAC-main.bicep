param workflows_IntuneRBAC_main_name string
param connections_SharePoint_name string = 'SharePointOnline'
param resourceLocation string 
param userAssignedIdentities_IntuneRBAC_Identity_name string = 'IntuneRBAC-ManagedIdentity'

resource workflows_IntuneRBAC_main_nameresource 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflows_IntuneRBAC_main_name
  location: resourceLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities/',userAssignedIdentities_IntuneRBAC_Identity_name)}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Week'
            interval: 1
          }
          evaluatedRecurrence: {
            frequency: 'Week'
            interval: 1
          }
          type: 'Recurrence'
        }
      }
      actions: {
        'CountryBasedGroups-IntuneRBAC': {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'UserGroupIDs'
                type: 'object'
                value: {
                  groupIds: [
                    '00000-00000'
                    '00000-00000'
                  ]
                }
              }
            ]
          }
        }
        For_each_ManagedDevice_Android: {
          foreach: '@body(\'Parse_JSON_Get_Android_devices\')?[\'value\']'
          actions: {
            Condition_UserPrincipalName__Android: {
              actions: {
                For_each_Group_memership_Android: {
                  foreach: '@body(\'Parse_JSON_Check_User_Group_Membership_Android\')?[\'value\']'
                  actions: {
                    For_each_AADDevice_ID__Android: {
                      foreach: '@body(\'Parse_JSON_Get_AADDevice__Android\')?[\'value\']'
                      actions: {
                        For_each_Android_GroupObjectID: {
                          foreach: '@body(\'Get_items_Android\')?[\'value\']'
                          actions: {
                            Condition_Device_MemberOf_Android: {
                              actions: {
                                HTTP_Add_Group_Member__Android: {
                                  runAfter: {}
                                  type: 'Http'
                                  inputs: {
                                    authentication: {
                                      audience: 'https://graph.microsoft.com'
                                      identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                                      type: 'ManagedServiceIdentity'
                                    }
                                    body: {
                                      '@@odata.id': 'https://graph.microsoft.com/v1.0/devices/@{items(\'For_each_AADDevice_ID__Android\')?[\'id\']}'
                                    }
                                    method: 'POST'
                                    uri: 'https://graph.microsoft.com/v1.0/groups/@{items(\'For_each_Android_GroupObjectID\')?[\'AndroidDeviceGroupObjectID\']}/members/$ref'
                                  }
                                }
                              }
                              runAfter: {
                                HTTP_GET_Device_MemberOf_Android: [
                                  'Succeeded'
                                  'Failed'
                                ]
                              }
                              expression: {
                                and: [
                                  {
                                    equals: [
                                      '@outputs(\'HTTP_GET_Device_MemberOf_Android\')[\'statusCode\']'
                                      404
                                    ]
                                  }
                                ]
                              }
                              type: 'If'
                            }
                            HTTP_GET_Device_MemberOf_Android: {
                              runAfter: {}
                              type: 'Http'
                              inputs: {
                                authentication: {
                                  audience: 'https://graph.microsoft.com'
                                  identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                                  type: 'ManagedServiceIdentity'
                                }
                                method: 'GET'
                                uri: 'https://graph.microsoft.com/v1.0/devices/@{items(\'For_each_AADDevice_ID__Android\')?[\'id\']}/memberOf/@{items(\'For_each_Android_GroupObjectID\')?[\'AndroidDeviceGroupObjectID\']}'
                              }
                            }
                          }
                          runAfter: {}
                          type: 'Foreach'
                        }
                      }
                      runAfter: {
                        Get_items_Android: [
                          'Succeeded'
                        ]
                      }
                      type: 'Foreach'
                    }
                    Get_items_Android: {
                      runAfter: {}
                      type: 'ApiConnection'
                      inputs: {
                        host: {
                          connection: {
                            name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
                          }
                        }
                        method: 'get'
                        path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'\'))}/tables/@{encodeURIComponent(encodeURIComponent(\'\'))}/items'
                        queries: {
                          '$filter': 'UserGroupObjectID eq \'@{items(\'For_each_Group_memership_Android\')}\''
                        }
                      }
                    }
                  }
                  runAfter: {
                    Parse_JSON_Check_User_Group_Membership_Android: [
                      'Succeeded'
                    ]
                  }
                  type: 'Foreach'
                }
                HTTP_Check_User_Group_Membership_Android: {
                  runAfter: {}
                  type: 'Http'
                  inputs: {
                    authentication: {
                      audience: 'https://graph.microsoft.com'
                      identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                      type: 'ManagedServiceIdentity'
                    }
                    body: '@variables(\'UserGroupIDs\')'
                    method: 'POST'
                    uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'For_each_ManagedDevice_Android\')?[\'userPrincipalName\']}/checkMemberGroups'
                  }
                }
                Parse_JSON_Check_User_Group_Membership_Android: {
                  runAfter: {
                    HTTP_Check_User_Group_Membership_Android: [
                      'Succeeded'
                    ]
                  }
                  type: 'ParseJson'
                  inputs: {
                    content: '@body(\'HTTP_Check_User_Group_Membership_Android\')'
                    schema: {
                      properties: {
                        '@@odata.context': {
                          type: 'string'
                        }
                        value: {
                          items: {
                            type: 'string'
                          }
                          type: 'array'
                        }
                      }
                      type: 'object'
                    }
                  }
                }
              }
              runAfter: {
                Parse_JSON_Get_AADDevice__Android: [
                  'Succeeded'
                ]
              }
              expression: {
                and: [
                  {
                    not: {
                      equals: [
                        '@items(\'For_each_ManagedDevice_Android\')?[\'userPrincipalName\']'
                        ''
                      ]
                    }
                  }
                ]
              }
              type: 'If'
            }
            HTTP_Get_AADDevice__Android: {
              runAfter: {}
              type: 'Http'
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com'
                  identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                  type: 'ManagedServiceIdentity'
                }
                method: 'GET'
                uri: 'https://graph.microsoft.com/v1.0/devices?$filter=(deviceId eq \'@{items(\'For_each_ManagedDevice_Android\')?[\'azureADDeviceId\']}\')&$select=id,deviceId,displayName'
              }
            }
            Parse_JSON_Get_AADDevice__Android: {
              runAfter: {
                HTTP_Get_AADDevice__Android: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
              inputs: {
                content: '@body(\'HTTP_Get_AADDevice__Android\')'
                schema: {
                  properties: {
                    '@@odata.context': {
                      type: 'string'
                    }
                    value: {
                      items: {
                        properties: {
                          deviceId: {
                            type: 'string'
                          }
                          displayName: {
                            type: 'string'
                          }
                          id: {
                            type: 'string'
                          }
                        }
                        required: [
                          'id'
                          'deviceId'
                          'displayName'
                        ]
                        type: 'object'
                      }
                      type: 'array'
                    }
                  }
                  type: 'object'
                }
              }
            }
          }
          runAfter: {
            Parse_JSON_Get_Android_devices: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_ManagedDevice_iOS: {
          foreach: '@body(\'Parse_JSON_Get_iOS_devices\')?[\'value\']'
          actions: {
            Condition_UserPrincipalName_iOS: {
              actions: {
                For_each_Group_memership_iOS: {
                  foreach: '@body(\'Parse_JSON_Check_User_Group_Membership_iOS\')?[\'value\']'
                  actions: {
                    For_each_AADDevice_ID_iOS: {
                      foreach: '@body(\'Parse_JSON_Get_AADDevice_iOS\')?[\'value\']'
                      actions: {
                        For_each_iOS_GroupObjectID: {
                          foreach: '@body(\'Get_items_iOS\')?[\'value\']'
                          actions: {
                            Condition_Device_MemberOf_iOS: {
                              actions: {
                                HTTP_Add_Group_Member_iOS: {
                                  runAfter: {}
                                  type: 'Http'
                                  inputs: {
                                    authentication: {
                                      audience: 'https://graph.microsoft.com'
                                      identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                                      type: 'ManagedServiceIdentity'
                                    }
                                    body: {
                                      '@@odata.id': 'https://graph.microsoft.com/v1.0/devices/@{items(\'For_each_AADDevice_ID_iOS\')?[\'id\']}'
                                    }
                                    method: 'POST'
                                    uri: 'https://graph.microsoft.com/v1.0/groups/@{items(\'For_each_iOS_GroupObjectID\')?[\'iOSDeviceGroupObjectID\']}/members/$ref'
                                  }
                                }
                              }
                              runAfter: {
                                HTTP_GET_Device_MemberOf_iOS: [
                                  'Succeeded'
                                  'Failed'
                                ]
                              }
                              expression: {
                                and: [
                                  {
                                    equals: [
                                      '@outputs(\'HTTP_GET_Device_MemberOf_iOS\')[\'statusCode\']'
                                      404
                                    ]
                                  }
                                ]
                              }
                              type: 'If'
                            }
                            HTTP_GET_Device_MemberOf_iOS: {
                              runAfter: {}
                              type: 'Http'
                              inputs: {
                                authentication: {
                                  audience: 'https://graph.microsoft.com'
                                  identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                                  type: 'ManagedServiceIdentity'
                                }
                                method: 'GET'
                                uri: 'https://graph.microsoft.com/v1.0/devices/@{items(\'For_each_AADDevice_ID_iOS\')?[\'id\']}/memberOf/@{items(\'For_each_iOS_GroupObjectID\')?[\'iOSDeviceGroupObjectID\']}'
                              }
                            }
                          }
                          runAfter: {}
                          type: 'Foreach'
                        }
                      }
                      runAfter: {
                        Get_items_iOS: [
                          'Succeeded'
                        ]
                      }
                      type: 'Foreach'
                    }
                    Get_items_iOS: {
                      runAfter: {}
                      type: 'ApiConnection'
                      inputs: {
                        host: {
                          connection: {
                            name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
                          }
                        }
                        method: 'get'
                        path: '/datasets/@{encodeURIComponent(encodeURIComponent(\'\'))}/tables/@{encodeURIComponent(encodeURIComponent(\'\'))}/items'
                        queries: {
                          '$filter': 'UserGroupObjectID eq \'@{items(\'For_each_Group_memership_iOS\')}\''
                        }
                      }
                    }
                  }
                  runAfter: {
                    Parse_JSON_Check_User_Group_Membership_iOS: [
                      'Succeeded'
                    ]
                  }
                  type: 'Foreach'
                }
                HTTP_Check_User_Group_Membership_iOS: {
                  runAfter: {}
                  type: 'Http'
                  inputs: {
                    authentication: {
                      audience: 'https://graph.microsoft.com'
                      identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                      type: 'ManagedServiceIdentity'
                    }
                    body: '@variables(\'UserGroupIDs\')'
                    method: 'POST'
                    uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'For_each_ManagedDevice_iOS\')?[\'userPrincipalName\']}/checkMemberGroups'
                  }
                }
                Parse_JSON_Check_User_Group_Membership_iOS: {
                  runAfter: {
                    HTTP_Check_User_Group_Membership_iOS: [
                      'Succeeded'
                    ]
                  }
                  type: 'ParseJson'
                  inputs: {
                    content: '@body(\'HTTP_Check_User_Group_Membership_iOS\')'
                    schema: {
                      properties: {
                        '@@odata.context': {
                          type: 'string'
                        }
                        value: {
                          items: {
                            type: 'string'
                          }
                          type: 'array'
                        }
                      }
                      type: 'object'
                    }
                  }
                }
              }
              runAfter: {
                Parse_JSON_Get_AADDevice_iOS: [
                  'Succeeded'
                ]
              }
              expression: {
                and: [
                  {
                    not: {
                      equals: [
                        '@items(\'For_each_ManagedDevice_iOS\')?[\'userPrincipalName\']'
                        ''
                      ]
                    }
                  }
                ]
              }
              type: 'If'
            }
            HTTP_Get_AADDevice_iOS: {
              runAfter: {}
              type: 'Http'
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com'
                  identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
                  type: 'ManagedServiceIdentity'
                }
                method: 'GET'
                uri: 'https://graph.microsoft.com/v1.0/devices?$filter=(deviceId eq \'@{items(\'For_each_ManagedDevice_iOS\')?[\'azureADDeviceId\']}\')&$select=id,deviceId,displayName'
              }
            }
            Parse_JSON_Get_AADDevice_iOS: {
              runAfter: {
                HTTP_Get_AADDevice_iOS: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
              inputs: {
                content: '@body(\'HTTP_Get_AADDevice_iOS\')'
                schema: {
                  properties: {
                    '@@odata.context': {
                      type: 'string'
                    }
                    value: {
                      items: {
                        properties: {
                          deviceId: {
                            type: 'string'
                          }
                          displayName: {
                            type: 'string'
                          }
                          id: {
                            type: 'string'
                          }
                        }
                        required: [
                          'id'
                          'deviceId'
                          'displayName'
                        ]
                        type: 'object'
                      }
                      type: 'array'
                    }
                  }
                  type: 'object'
                }
              }
            }
          }
          runAfter: {
            Parse_JSON_Get_iOS_devices: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        HTTP_Get_Android_devices: {
          runAfter: {
            'CountryBasedGroups-IntuneRBAC': [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              audience: 'https://graph.microsoft.com'
              identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
              type: 'ManagedServiceIdentity'
            }
            method: 'GET'
            uri: 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=((((deviceType%20eq%20\'android\')%20or%20(deviceType%20eq%20\'androidForWork\')%20or%20(deviceType%20eq%20\'androidnGMS\'))%20or%20((deviceType%20eq%20\'androidEnterprise\')%20and%20((deviceEnrollmentType%20eq%20\'androidEnterpriseDedicatedDevice\')%20or%20(deviceEnrollmentType%20eq%20\'androidEnterpriseFullyManaged\')%20or%20(deviceEnrollmentType%20eq%20\'androidEnterpriseCorporateWorkProfile\')))))'
          }
          runtimeConfiguration: {
            paginationPolicy: {
              minimumItemCount: 25000
            }
          }
        }
        HTTP_Get_iOS_devices: {
          runAfter: {
            'CountryBasedGroups-IntuneRBAC': [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              audience: 'https://graph.microsoft.com'
              identity: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentities_IntuneRBAC_Identity_name)
              type: 'ManagedServiceIdentity'
            }
            method: 'GET'
            uri: 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=(((deviceType%20eq%20\'iPad\')%20or%20(deviceType%20eq%20\'iPhone\')%20or%20(deviceType%20eq%20\'iPod\')))'
          }
          runtimeConfiguration: {
            paginationPolicy: {
              minimumItemCount: 25000
            }
          }
        }
        Parse_JSON_Get_Android_devices: {
          runAfter: {
            HTTP_Get_Android_devices: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'HTTP_Get_Android_devices\')'
            schema: {
              properties: {
                '@@odata.context': {
                  type: 'string'
                }
                '@@odata.count': {
                  type: 'integer'
                }
                value: {
                  items: {
                    properties: {
                      aadRegistered: {}
                      activationLockBypassCode: {}
                      androidSecurityPatchLevel: {
                        type: 'string'
                      }
                      autopilotEnrolled: {
                        type: 'boolean'
                      }
                      azureADDeviceId: {
                        type: 'string'
                      }
                      azureADRegistered: {}
                      azureActiveDirectoryDeviceId: {
                        type: 'string'
                      }
                      chassisType: {
                        type: 'string'
                      }
                      chromeOSDeviceInfo: {
                        type: 'array'
                      }
                      complianceGracePeriodExpirationDateTime: {
                        type: 'string'
                      }
                      complianceState: {
                        type: 'string'
                      }
                      configurationManagerClientEnabledFeatures: {}
                      configurationManagerClientHealthState: {}
                      configurationManagerClientInformation: {}
                      deviceActionResults: {
                        type: 'array'
                      }
                      deviceCategoryDisplayName: {
                        type: 'string'
                      }
                      deviceEnrollmentType: {
                        type: 'string'
                      }
                      deviceHealthAttestationState: {}
                      deviceName: {
                        type: 'string'
                      }
                      deviceRegistrationState: {
                        type: 'string'
                      }
                      deviceType: {
                        type: 'string'
                      }
                      easActivated: {
                        type: 'boolean'
                      }
                      easActivationDateTime: {
                        type: 'string'
                      }
                      easDeviceId: {
                        type: 'string'
                      }
                      emailAddress: {
                        type: 'string'
                      }
                      enrolledDateTime: {
                        type: 'string'
                      }
                      enrollmentProfileName: {}
                      ethernetMacAddress: {}
                      exchangeAccessState: {
                        type: 'string'
                      }
                      exchangeAccessStateReason: {
                        type: 'string'
                      }
                      exchangeLastSuccessfulSyncDateTime: {
                        type: 'string'
                      }
                      freeStorageSpaceInBytes: {
                        type: 'integer'
                      }
                      hardwareInformation: {
                        properties: {
                          batteryChargeCycles: {
                            type: 'integer'
                          }
                          batteryHealthPercentage: {
                            type: 'integer'
                          }
                          batterySerialNumber: {}
                          cellularTechnology: {}
                          deviceFullQualifiedDomainName: {}
                          deviceGuardLocalSystemAuthorityCredentialGuardState: {
                            type: 'string'
                          }
                          deviceGuardVirtualizationBasedSecurityHardwareRequirementState: {
                            type: 'string'
                          }
                          deviceGuardVirtualizationBasedSecurityState: {
                            type: 'string'
                          }
                          esimIdentifier: {}
                          freeStorageSpace: {
                            type: 'integer'
                          }
                          imei: {
                            type: 'string'
                          }
                          ipAddressV4: {}
                          isEncrypted: {
                            type: 'boolean'
                          }
                          isSharedDevice: {
                            type: 'boolean'
                          }
                          isSupervised: {
                            type: 'boolean'
                          }
                          manufacturer: {}
                          meid: {}
                          model: {}
                          operatingSystemEdition: {}
                          operatingSystemLanguage: {}
                          operatingSystemProductType: {
                            type: 'integer'
                          }
                          osBuildNumber: {}
                          phoneNumber: {}
                          serialNumber: {
                            type: 'string'
                          }
                          sharedDeviceCachedUsers: {
                            type: 'array'
                          }
                          subnetAddress: {}
                          subscriberCarrier: {}
                          systemManagementBIOSVersion: {}
                          totalStorageSpace: {
                            type: 'integer'
                          }
                          tpmManufacturer: {}
                          tpmSpecificationVersion: {}
                          tpmVersion: {}
                          wifiMac: {}
                        }
                        type: 'object'
                      }
                      iccid: {}
                      id: {
                        type: 'string'
                      }
                      imei: {
                        type: 'string'
                      }
                      isEncrypted: {
                        type: 'boolean'
                      }
                      isSupervised: {
                        type: 'boolean'
                      }
                      jailBroken: {
                        type: 'string'
                      }
                      joinType: {
                        type: 'string'
                      }
                      lastSyncDateTime: {
                        type: 'string'
                      }
                      lostModeState: {
                        type: 'string'
                      }
                      managedDeviceName: {
                        type: 'string'
                      }
                      managedDeviceOwnerType: {
                        type: 'string'
                      }
                      managementAgent: {
                        type: 'string'
                      }
                      managementCertificateExpirationDate: {
                        type: 'string'
                      }
                      managementFeatures: {
                        type: 'string'
                      }
                      managementState: {
                        type: 'string'
                      }
                      manufacturer: {
                        type: 'string'
                      }
                      meid: {
                        type: 'string'
                      }
                      model: {
                        type: 'string'
                      }
                      notes: {}
                      operatingSystem: {
                        type: 'string'
                      }
                      osVersion: {
                        type: 'string'
                      }
                      ownerType: {
                        type: 'string'
                      }
                      partnerReportedThreatState: {
                        type: 'string'
                      }
                      phoneNumber: {
                        type: 'string'
                      }
                      physicalMemoryInBytes: {
                        type: 'integer'
                      }
                      preferMdmOverGroupPolicyAppliedDateTime: {
                        type: 'string'
                      }
                      processorArchitecture: {
                        type: 'string'
                      }
                      remoteAssistanceSessionErrorDetails: {}
                      remoteAssistanceSessionUrl: {}
                      requireUserEnrollmentApproval: {}
                      retireAfterDateTime: {
                        type: 'string'
                      }
                      roleScopeTagIds: {
                        type: 'array'
                      }
                      serialNumber: {
                        type: 'string'
                      }
                      skuFamily: {
                        type: 'string'
                      }
                      skuNumber: {
                        type: 'integer'
                      }
                      specificationVersion: {}
                      subscriberCarrier: {
                        type: 'string'
                      }
                      totalStorageSpaceInBytes: {
                        type: 'integer'
                      }
                      udid: {}
                      userDisplayName: {
                        type: 'string'
                      }
                      userId: {
                        type: 'string'
                      }
                      userPrincipalName: {
                        type: 'string'
                      }
                      usersLoggedOn: {
                        type: 'array'
                      }
                      wiFiMacAddress: {
                        type: 'string'
                      }
                      windowsActiveMalwareCount: {
                        type: 'integer'
                      }
                      windowsRemediatedMalwareCount: {
                        type: 'integer'
                      }
                    }
                    required: [
                      'id'
                      'userId'
                      'deviceName'
                      'ownerType'
                      'managedDeviceOwnerType'
                      'managementState'
                      'enrolledDateTime'
                      'lastSyncDateTime'
                      'chassisType'
                      'operatingSystem'
                      'deviceType'
                      'complianceState'
                      'jailBroken'
                      'managementAgent'
                      'osVersion'
                      'easActivated'
                      'easDeviceId'
                      'easActivationDateTime'
                      'aadRegistered'
                      'azureADRegistered'
                      'deviceEnrollmentType'
                      'lostModeState'
                      'activationLockBypassCode'
                      'emailAddress'
                      'azureActiveDirectoryDeviceId'
                      'azureADDeviceId'
                      'deviceRegistrationState'
                      'deviceCategoryDisplayName'
                      'isSupervised'
                      'exchangeLastSuccessfulSyncDateTime'
                      'exchangeAccessState'
                      'exchangeAccessStateReason'
                      'remoteAssistanceSessionUrl'
                      'remoteAssistanceSessionErrorDetails'
                      'isEncrypted'
                      'userPrincipalName'
                      'model'
                      'manufacturer'
                      'imei'
                      'complianceGracePeriodExpirationDateTime'
                      'serialNumber'
                      'phoneNumber'
                      'androidSecurityPatchLevel'
                      'userDisplayName'
                      'configurationManagerClientEnabledFeatures'
                      'wiFiMacAddress'
                      'deviceHealthAttestationState'
                      'subscriberCarrier'
                      'meid'
                      'totalStorageSpaceInBytes'
                      'freeStorageSpaceInBytes'
                      'managedDeviceName'
                      'partnerReportedThreatState'
                      'retireAfterDateTime'
                      'preferMdmOverGroupPolicyAppliedDateTime'
                      'autopilotEnrolled'
                      'requireUserEnrollmentApproval'
                      'managementCertificateExpirationDate'
                      'iccid'
                      'udid'
                      'roleScopeTagIds'
                      'windowsActiveMalwareCount'
                      'windowsRemediatedMalwareCount'
                      'notes'
                      'configurationManagerClientHealthState'
                      'configurationManagerClientInformation'
                      'ethernetMacAddress'
                      'physicalMemoryInBytes'
                      'processorArchitecture'
                      'specificationVersion'
                      'joinType'
                      'skuFamily'
                      'skuNumber'
                      'managementFeatures'
                      'enrollmentProfileName'
                      'hardwareInformation'
                      'deviceActionResults'
                      'usersLoggedOn'
                      'chromeOSDeviceInfo'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_JSON_Get_iOS_devices: {
          runAfter: {
            HTTP_Get_iOS_devices: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'HTTP_Get_iOS_devices\')'
            schema: {
              properties: {
                '@@odata.context': {
                  type: 'string'
                }
                '@@odata.count': {
                  type: 'integer'
                }
                value: {
                  items: {
                    properties: {
                      aadRegistered: {}
                      activationLockBypassCode: {}
                      androidSecurityPatchLevel: {
                        type: 'string'
                      }
                      autopilotEnrolled: {
                        type: 'boolean'
                      }
                      azureADDeviceId: {
                        type: 'string'
                      }
                      azureADRegistered: {}
                      azureActiveDirectoryDeviceId: {
                        type: 'string'
                      }
                      chassisType: {
                        type: 'string'
                      }
                      chromeOSDeviceInfo: {
                        type: 'array'
                      }
                      complianceGracePeriodExpirationDateTime: {
                        type: 'string'
                      }
                      complianceState: {
                        type: 'string'
                      }
                      configurationManagerClientEnabledFeatures: {}
                      configurationManagerClientHealthState: {}
                      configurationManagerClientInformation: {}
                      deviceActionResults: {
                        type: 'array'
                      }
                      deviceCategoryDisplayName: {
                        type: 'string'
                      }
                      deviceEnrollmentType: {
                        type: 'string'
                      }
                      deviceHealthAttestationState: {}
                      deviceName: {
                        type: 'string'
                      }
                      deviceRegistrationState: {
                        type: 'string'
                      }
                      deviceType: {
                        type: 'string'
                      }
                      easActivated: {
                        type: 'boolean'
                      }
                      easActivationDateTime: {
                        type: 'string'
                      }
                      easDeviceId: {
                        type: 'string'
                      }
                      emailAddress: {
                        type: 'string'
                      }
                      enrolledDateTime: {
                        type: 'string'
                      }
                      enrollmentProfileName: {}
                      ethernetMacAddress: {}
                      exchangeAccessState: {
                        type: 'string'
                      }
                      exchangeAccessStateReason: {
                        type: 'string'
                      }
                      exchangeLastSuccessfulSyncDateTime: {
                        type: 'string'
                      }
                      freeStorageSpaceInBytes: {
                        type: 'integer'
                      }
                      hardwareInformation: {
                        properties: {
                          batteryChargeCycles: {
                            type: 'integer'
                          }
                          batteryHealthPercentage: {
                            type: 'integer'
                          }
                          batterySerialNumber: {}
                          cellularTechnology: {}
                          deviceFullQualifiedDomainName: {}
                          deviceGuardLocalSystemAuthorityCredentialGuardState: {
                            type: 'string'
                          }
                          deviceGuardVirtualizationBasedSecurityHardwareRequirementState: {
                            type: 'string'
                          }
                          deviceGuardVirtualizationBasedSecurityState: {
                            type: 'string'
                          }
                          esimIdentifier: {}
                          freeStorageSpace: {
                            type: 'integer'
                          }
                          imei: {
                            type: 'string'
                          }
                          ipAddressV4: {}
                          isEncrypted: {
                            type: 'boolean'
                          }
                          isSharedDevice: {
                            type: 'boolean'
                          }
                          isSupervised: {
                            type: 'boolean'
                          }
                          manufacturer: {}
                          meid: {}
                          model: {}
                          operatingSystemEdition: {}
                          operatingSystemLanguage: {}
                          operatingSystemProductType: {
                            type: 'integer'
                          }
                          osBuildNumber: {}
                          phoneNumber: {}
                          serialNumber: {
                            type: 'string'
                          }
                          sharedDeviceCachedUsers: {
                            type: 'array'
                          }
                          subnetAddress: {}
                          subscriberCarrier: {}
                          systemManagementBIOSVersion: {}
                          totalStorageSpace: {
                            type: 'integer'
                          }
                          tpmManufacturer: {}
                          tpmSpecificationVersion: {}
                          tpmVersion: {}
                          wifiMac: {}
                        }
                        type: 'object'
                      }
                      iccid: {}
                      id: {
                        type: 'string'
                      }
                      imei: {
                        type: 'string'
                      }
                      isEncrypted: {
                        type: 'boolean'
                      }
                      isSupervised: {
                        type: 'boolean'
                      }
                      jailBroken: {
                        type: 'string'
                      }
                      joinType: {
                        type: 'string'
                      }
                      lastSyncDateTime: {
                        type: 'string'
                      }
                      lostModeState: {
                        type: 'string'
                      }
                      managedDeviceName: {
                        type: 'string'
                      }
                      managedDeviceOwnerType: {
                        type: 'string'
                      }
                      managementAgent: {
                        type: 'string'
                      }
                      managementCertificateExpirationDate: {
                        type: 'string'
                      }
                      managementFeatures: {
                        type: 'string'
                      }
                      managementState: {
                        type: 'string'
                      }
                      manufacturer: {
                        type: 'string'
                      }
                      meid: {
                        type: 'string'
                      }
                      model: {
                        type: 'string'
                      }
                      notes: {}
                      operatingSystem: {
                        type: 'string'
                      }
                      osVersion: {
                        type: 'string'
                      }
                      ownerType: {
                        type: 'string'
                      }
                      partnerReportedThreatState: {
                        type: 'string'
                      }
                      phoneNumber: {
                        type: 'string'
                      }
                      physicalMemoryInBytes: {
                        type: 'integer'
                      }
                      preferMdmOverGroupPolicyAppliedDateTime: {
                        type: 'string'
                      }
                      processorArchitecture: {
                        type: 'string'
                      }
                      remoteAssistanceSessionErrorDetails: {}
                      remoteAssistanceSessionUrl: {}
                      requireUserEnrollmentApproval: {}
                      retireAfterDateTime: {
                        type: 'string'
                      }
                      roleScopeTagIds: {
                        type: 'array'
                      }
                      serialNumber: {
                        type: 'string'
                      }
                      skuFamily: {
                        type: 'string'
                      }
                      skuNumber: {
                        type: 'integer'
                      }
                      specificationVersion: {}
                      subscriberCarrier: {
                        type: 'string'
                      }
                      totalStorageSpaceInBytes: {
                        type: 'integer'
                      }
                      udid: {}
                      userDisplayName: {
                        type: 'string'
                      }
                      userId: {
                        type: 'string'
                      }
                      userPrincipalName: {
                        type: 'string'
                      }
                      usersLoggedOn: {
                        type: 'array'
                      }
                      wiFiMacAddress: {
                        type: 'string'
                      }
                      windowsActiveMalwareCount: {
                        type: 'integer'
                      }
                      windowsRemediatedMalwareCount: {
                        type: 'integer'
                      }
                    }
                    required: [
                      'id'
                      'userId'
                      'deviceName'
                      'ownerType'
                      'managedDeviceOwnerType'
                      'managementState'
                      'enrolledDateTime'
                      'lastSyncDateTime'
                      'chassisType'
                      'operatingSystem'
                      'deviceType'
                      'complianceState'
                      'jailBroken'
                      'managementAgent'
                      'osVersion'
                      'easActivated'
                      'easDeviceId'
                      'easActivationDateTime'
                      'aadRegistered'
                      'azureADRegistered'
                      'deviceEnrollmentType'
                      'lostModeState'
                      'activationLockBypassCode'
                      'emailAddress'
                      'azureActiveDirectoryDeviceId'
                      'azureADDeviceId'
                      'deviceRegistrationState'
                      'deviceCategoryDisplayName'
                      'isSupervised'
                      'exchangeLastSuccessfulSyncDateTime'
                      'exchangeAccessState'
                      'exchangeAccessStateReason'
                      'remoteAssistanceSessionUrl'
                      'remoteAssistanceSessionErrorDetails'
                      'isEncrypted'
                      'userPrincipalName'
                      'model'
                      'manufacturer'
                      'imei'
                      'complianceGracePeriodExpirationDateTime'
                      'serialNumber'
                      'phoneNumber'
                      'androidSecurityPatchLevel'
                      'userDisplayName'
                      'configurationManagerClientEnabledFeatures'
                      'wiFiMacAddress'
                      'deviceHealthAttestationState'
                      'subscriberCarrier'
                      'meid'
                      'totalStorageSpaceInBytes'
                      'freeStorageSpaceInBytes'
                      'managedDeviceName'
                      'partnerReportedThreatState'
                      'retireAfterDateTime'
                      'preferMdmOverGroupPolicyAppliedDateTime'
                      'autopilotEnrolled'
                      'requireUserEnrollmentApproval'
                      'managementCertificateExpirationDate'
                      'iccid'
                      'udid'
                      'roleScopeTagIds'
                      'windowsActiveMalwareCount'
                      'windowsRemediatedMalwareCount'
                      'notes'
                      'configurationManagerClientHealthState'
                      'configurationManagerClientInformation'
                      'ethernetMacAddress'
                      'physicalMemoryInBytes'
                      'processorArchitecture'
                      'specificationVersion'
                      'joinType'
                      'skuFamily'
                      'skuNumber'
                      'managementFeatures'
                      'enrollmentProfileName'
                      'hardwareInformation'
                      'deviceActionResults'
                      'usersLoggedOn'
                      'chromeOSDeviceInfo'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          sharepointonline: {
            connectionId: resourceId('Microsoft.Web/connections', connections_SharePoint_name)
            connectionName: 'SharePointOnline'
            id: '${subscription().id}/providers/Microsoft.Web/locations/${resourceLocation}/managedApis/SharePointOnline'
          }
        }
      }
    }
  }
}
