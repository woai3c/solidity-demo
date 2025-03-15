# Slither安全分析报告

## 分析结果

```json
{
  "success": true,
  "error": null,
  "results": {
    "detectors": [
      {
        "elements": [
          {
            "type": "variable",
            "name": "owner",
            "source_mapping": {
              "start": 3619,
              "length": 13,
              "filename_relative": "contracts/MyToken.sol",
              "filename_absolute": "/tmp/audit-work/contracts/MyToken.sol",
              "filename_short": "contracts/MyToken.sol",
              "is_dependency": false,
              "lines": [110],
              "starting_column": 22,
              "ending_column": 35
            },
            "type_specific_fields": {
              "parent": {
                "type": "function",
                "name": "allowance",
                "source_mapping": {
                  "start": 3600,
                  "length": 137,
                  "filename_relative": "contracts/MyToken.sol",
                  "filename_absolute": "/tmp/audit-work/contracts/MyToken.sol",
                  "filename_short": "contracts/MyToken.sol",
                  "is_dependency": false,
                  "lines": [110, 111, 112],
                  "starting_column": 3,
                  "ending_column": 4
                },
                "type_specific_fields": {
                  "parent": {
                    "type": "contract",
                    "name": "MyToken",
                    "source_mapping": {
                      "start": 422,
                      "length": 6412,
                      "filename_relative": "contracts/MyToken.sol",
                      "filename_absolute": "/tmp/audit-work/contracts/MyToken.sol",
                      "filename_short": "contracts/MyToken.sol",
                      "is_dependency": false,
                      "lines": [
                        9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
                        33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56,
                        57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
                        81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103,
                        104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,
                        123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141,
                        142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
                        161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179,
                        180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198,
                        199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217,
                        218, 219, 220, 221, 222, 223, 224, 225, 226
                      ],
                      "starting_column": 1,
                      "ending_column": 2
                    }
                  },
                  "signature": "allowance(address,address)"
                }
              }
            }
          },
          {
            "type": "function",
            "name": "owner",
            "source_mapping": {
              "start": 1638,
              "length": 85,
              "filename_relative": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "is_dependency": false,
              "lines": [56, 57, 58],
              "starting_column": 5,
              "ending_column": 6
            },
            "type_specific_fields": {
              "parent": {
                "type": "contract",
                "name": "Ownable",
                "source_mapping": {
                  "start": 663,
                  "length": 2438,
                  "filename_relative": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
                  "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/access/Ownable.sol",
                  "filename_short": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
                  "is_dependency": false,
                  "lines": [
                    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
                    45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
                    70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94,
                    95, 96, 97, 98, 99, 100
                  ],
                  "starting_column": 1,
                  "ending_column": 2
                }
              },
              "signature": "owner()"
            }
          }
        ],
        "description": "MyToken.allowance(address,address).owner (contracts/MyToken.sol#110) shadows:\n\t- Ownable.owner() (node_modules/@openzeppelin/contracts/access/Ownable.sol#56-58) (function)\n",
        "markdown": "[MyToken.allowance(address,address).owner](contracts/MyToken.sol#L110) shadows:\n\t- [Ownable.owner()](node_modules/@openzeppelin/contracts/access/Ownable.sol#L56-L58) (function)\n",
        "first_markdown_element": "contracts/MyToken.sol#L110",
        "id": "7bf2b554e18516fdfb94aa53faf9ee9477c58a7ec29e2ae144f77898d7ff0e04",
        "check": "shadowing-local",
        "impact": "Low",
        "confidence": "High"
      },
      {
        "elements": [
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 32,
              "length": 24,
              "filename_relative": "contracts/MyToken.sol",
              "filename_absolute": "/tmp/audit-work/contracts/MyToken.sol",
              "filename_short": "contracts/MyToken.sol",
              "is_dependency": false,
              "lines": [2],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".26"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 102,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 106,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 101,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 102,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 109,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          }
        ],
        "description": "2 different versions of Solidity are used:\n\t- Version constraint ^0.8.20 is used by:\n\t\t-^0.8.20 (contracts/MyToken.sol#2)\n\t- Version constraint ^0.8.20 is used by:\n\t\t-^0.8.20 (node_modules/@openzeppelin/contracts/access/Ownable.sol#4)\n\t\t-^0.8.20 (node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol#4)\n\t\t-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Context.sol#4)\n\t\t-^0.8.20 (node_modules/@openzeppelin/contracts/utils/Pausable.sol#4)\n\t\t-^0.8.20 (node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#4)\n",
        "markdown": "2 different versions of Solidity are used:\n\t- Version constraint ^0.8.20 is used by:\n\t\t-[^0.8.20](contracts/MyToken.sol#L2)\n\t- Version constraint ^0.8.20 is used by:\n\t\t-[^0.8.20](node_modules/@openzeppelin/contracts/access/Ownable.sol#L4)\n\t\t-[^0.8.20](node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol#L4)\n\t\t-[^0.8.20](node_modules/@openzeppelin/contracts/utils/Context.sol#L4)\n\t\t-[^0.8.20](node_modules/@openzeppelin/contracts/utils/Pausable.sol#L4)\n\t\t-[^0.8.20](node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#L4)\n",
        "first_markdown_element": "contracts/MyToken.sol#L2",
        "id": "f2521816afdd4a873ed3f73f48c71b49f4c37894170de3ade05ddc7a4a976b32",
        "check": "pragma",
        "impact": "Informational",
        "confidence": "High"
      },
      {
        "elements": [
          {
            "type": "function",
            "name": "_contextSuffixLength",
            "source_mapping": {
              "start": 863,
              "length": 97,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "is_dependency": false,
              "lines": [25, 26, 27],
              "starting_column": 5,
              "ending_column": 6
            },
            "type_specific_fields": {
              "parent": {
                "type": "contract",
                "name": "Context",
                "source_mapping": {
                  "start": 624,
                  "length": 338,
                  "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "is_dependency": false,
                  "lines": [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
                  "starting_column": 1,
                  "ending_column": 2
                }
              },
              "signature": "_contextSuffixLength()"
            }
          }
        ],
        "description": "Context._contextSuffixLength() (node_modules/@openzeppelin/contracts/utils/Context.sol#25-27) is never used and should be removed\n",
        "markdown": "[Context._contextSuffixLength()](node_modules/@openzeppelin/contracts/utils/Context.sol#L25-L27) is never used and should be removed\n",
        "first_markdown_element": "node_modules/@openzeppelin/contracts/utils/Context.sol#L25-L27",
        "id": "10de43c0e01930a1b9fb40f4f6ed72c2f999387cc16e08f742e274689dd237ba",
        "check": "dead-code",
        "impact": "Informational",
        "confidence": "Medium"
      },
      {
        "elements": [
          {
            "type": "function",
            "name": "_msgData",
            "source_mapping": {
              "start": 758,
              "length": 99,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "is_dependency": false,
              "lines": [21, 22, 23],
              "starting_column": 5,
              "ending_column": 6
            },
            "type_specific_fields": {
              "parent": {
                "type": "contract",
                "name": "Context",
                "source_mapping": {
                  "start": 624,
                  "length": 338,
                  "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
                  "is_dependency": false,
                  "lines": [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
                  "starting_column": 1,
                  "ending_column": 2
                }
              },
              "signature": "_msgData()"
            }
          }
        ],
        "description": "Context._msgData() (node_modules/@openzeppelin/contracts/utils/Context.sol#21-23) is never used and should be removed\n",
        "markdown": "[Context._msgData()](node_modules/@openzeppelin/contracts/utils/Context.sol#L21-L23) is never used and should be removed\n",
        "first_markdown_element": "node_modules/@openzeppelin/contracts/utils/Context.sol#L21-L23",
        "id": "93bd23634a3bf022810e43138345cf58db61248a704a7d277c8ec3d68c3ad188",
        "check": "dead-code",
        "impact": "Informational",
        "confidence": "Medium"
      },
      {
        "elements": [
          {
            "type": "function",
            "name": "_reentrancyGuardEntered",
            "source_mapping": {
              "start": 3275,
              "length": 106,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "is_dependency": false,
              "lines": [84, 85, 86],
              "starting_column": 5,
              "ending_column": 6
            },
            "type_specific_fields": {
              "parent": {
                "type": "contract",
                "name": "ReentrancyGuard",
                "source_mapping": {
                  "start": 1030,
                  "length": 2353,
                  "filename_relative": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
                  "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
                  "filename_short": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
                  "is_dependency": false,
                  "lines": [
                    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
                    50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74,
                    75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87
                  ],
                  "starting_column": 1,
                  "ending_column": 2
                }
              },
              "signature": "_reentrancyGuardEntered()"
            }
          }
        ],
        "description": "ReentrancyGuard._reentrancyGuardEntered() (node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#84-86) is never used and should be removed\n",
        "markdown": "[ReentrancyGuard._reentrancyGuardEntered()](node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#L84-L86) is never used and should be removed\n",
        "first_markdown_element": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#L84-L86",
        "id": "f2a370a5aa5b56667b20cd1751bdf54984703a0ff32bfdfa193b13ef7fd47b6e",
        "check": "dead-code",
        "impact": "Informational",
        "confidence": "Medium"
      },
      {
        "elements": [
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 102,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/access/Ownable.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 106,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 101,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Context.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Context.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 102,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/Pausable.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          },
          {
            "type": "pragma",
            "name": "^0.8.20",
            "source_mapping": {
              "start": 109,
              "length": 24,
              "filename_relative": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_absolute": "/tmp/audit-work/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "filename_short": "node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol",
              "is_dependency": false,
              "lines": [4],
              "starting_column": 1,
              "ending_column": 25
            },
            "type_specific_fields": {
              "directive": ["solidity", "^", "0.8", ".20"]
            }
          }
        ],
        "description": "Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- VerbatimInvalidDeduplication\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess.\nIt is used by:\n\t- ^0.8.20 (node_modules/@openzeppelin/contracts/access/Ownable.sol#4)\n\t- ^0.8.20 (node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol#4)\n\t- ^0.8.20 (node_modules/@openzeppelin/contracts/utils/Context.sol#4)\n\t- ^0.8.20 (node_modules/@openzeppelin/contracts/utils/Pausable.sol#4)\n\t- ^0.8.20 (node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#4)\n",
        "markdown": "Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- VerbatimInvalidDeduplication\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess.\nIt is used by:\n\t- [^0.8.20](node_modules/@openzeppelin/contracts/access/Ownable.sol#L4)\n\t- [^0.8.20](node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol#L4)\n\t- [^0.8.20](node_modules/@openzeppelin/contracts/utils/Context.sol#L4)\n\t- [^0.8.20](node_modules/@openzeppelin/contracts/utils/Pausable.sol#L4)\n\t- [^0.8.20](node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol#L4)\n",
        "first_markdown_element": "node_modules/@openzeppelin/contracts/access/Ownable.sol#L4",
        "id": "17393bc8206ea97df6dc98278092622c5935f1afa35d2895431c4198125344ec",
        "check": "solc-version",
        "impact": "Informational",
        "confidence": "High"
      }
    ]
  }
}
```
