#!/usr/bin/python3
"""
La plantilla «Apuntes» de Apogeo para ONLYOFFICE (y para «Crear nuevo» en Archivos): un .docx con Source Serif 4 en todo
(el texto a 12 pt y los títulos en negrita), A4 y en español. Se genera aquí, sin nada de fuera: un .docx es un zip con
unos pocos XML.

Uso: plantilla.py <salida.docx>
"""

import sys
import zipfile

LETRA = 'Source Serif 4'
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

TIPOS = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>'''

RELS = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>'''

DOC_RELS = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''

CORE = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:title>Apuntes</dc:title>
<dc:language>es-ES</dc:language>
</cp:coreProperties>'''


def fuente(tam, negrita=False, color=None):
    """Las propiedades de letra de un estilo (tam en medios puntos)."""
    return (f'<w:rPr><w:rFonts w:ascii="{LETRA}" w:hAnsi="{LETRA}" w:cs="{LETRA}" w:eastAsia="{LETRA}"/>'
            + ('<w:b/><w:bCs/>' if negrita else '')
            + (f'<w:color w:val="{color}"/>' if color else '')
            + f'<w:sz w:val="{tam}"/><w:szCs w:val="{tam}"/><w:lang w:val="es-ES"/></w:rPr>')


def titulo(id_, nombre, tam, antes, despues, nivel=None):
    return (f'<w:style w:type="paragraph" w:styleId="{id_}"><w:name w:val="{nombre}"/><w:basedOn w:val="Normal"/>'
            '<w:next w:val="Normal"/><w:qFormat/>'
            f'<w:pPr><w:keepNext/><w:spacing w:before="{antes}" w:after="{despues}" w:line="240" w:lineRule="auto"/>'
            + (f'<w:outlineLvl w:val="{nivel}"/>' if nivel is not None else '') + '</w:pPr>'
            + fuente(tam, True, '1F2430') + '</w:style>')


ESTILOS = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="{W}">'
           '<w:docDefaults><w:rPrDefault>' + fuente(24) + '</w:rPrDefault>'
           '<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
           '</w:docDefaults>'
           '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
           + titulo('Title', 'Title', 52, 0, 240)
           + titulo('Heading1', 'heading 1', 36, 360, 120, 0)
           + titulo('Heading2', 'heading 2', 29, 280, 100, 1)
           + titulo('Heading3', 'heading 3', 25, 240, 80, 2)
           + '</w:styles>')

DOCUMENTO = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="{W}"><w:body>'
             '<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t>Apuntes</w:t></w:r></w:p>'
             '<w:p/>'
             # A4 con márgenes de 2,5 cm
             '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
             '<w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/>'
             '</w:sectPr></w:body></w:document>')


def main():
    with zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED) as z:
        # (la fecha fija: el paquete sale igual cada vez)
        for nombre, datos in (('[Content_Types].xml', TIPOS), ('_rels/.rels', RELS), ('docProps/core.xml', CORE),
                              ('word/_rels/document.xml.rels', DOC_RELS), ('word/styles.xml', ESTILOS),
                              ('word/document.xml', DOCUMENTO)):
            z.writestr(zipfile.ZipInfo(nombre, (2026, 1, 1, 0, 0, 0)), datos, zipfile.ZIP_DEFLATED)


if __name__ == '__main__':
    main()
